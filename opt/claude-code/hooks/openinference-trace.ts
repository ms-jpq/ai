#!/usr/bin/env -S -- node

import type { HookInput, SessionMessage } from "@anthropic-ai/claude-agent-sdk"
import {
  getSessionMessages,
  getSubagentMessages,
} from "@anthropic-ai/claude-agent-sdk"
import type {
  BetaContentBlock,
  BetaContentBlockParam,
  BetaDocumentBlock,
  BetaMessage,
  BetaMessageParam,
  BetaRequestDocumentBlock,
} from "@anthropic-ai/sdk/resources/beta/messages/messages.js"
import {
  MimeType,
  OpenInferenceSpanKind,
  SemanticConventions,
} from "@arizeai/openinference-semantic-conventions"
import type { Link, Tracer } from "@opentelemetry/api"
import { SpanStatusCode } from "@opentelemetry/api"
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-proto"
import {
  BasicTracerProvider,
  SimpleSpanProcessor,
} from "@opentelemetry/sdk-trace-base"
import { fail } from "node:assert/strict"
import { execFile } from "node:child_process"
import { mkdir, readFile, rename, writeFile } from "node:fs/promises"
import { dirname, join, resolve } from "node:path"
import { env, stdin } from "node:process"
import { text } from "node:stream/consumers"
import { fileURLToPath } from "node:url"
import { promisify } from "node:util"

type Conf = Readonly<{ auth: string; host: string }>

type MessageBlock = string | BetaContentBlock | BetaContentBlockParam
type TranscriptMeta = Readonly<{
  timestamp: Date
  debugExpr: string
}>
const META: unique symbol = Symbol("transcript-meta")
type TranscriptMessage = Readonly<
  SessionMessage & {
    message: BetaMessage | BetaMessageParam
    timestamp: string
    [META]: TranscriptMeta
  }
>

type BaseExtractedBlock = Readonly<{
  type:
    | typeof SemanticConventions.INPUT_VALUE
    | typeof SemanticConventions.OUTPUT_VALUE
  kind: OpenInferenceSpanKind
  value: unknown
}>

type ExtractedBlock =
  | (BaseExtractedBlock & { category: "text" })
  | (BaseExtractedBlock & {
      category: "tool"
      correlationId: string | undefined
      error?: boolean
    })

type SourcedBlock = readonly [TranscriptMessage, ExtractedBlock]

type Correlated = readonly [SourcedBlock, SourcedBlock | undefined]

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..")
const SESSIONS_DIR = resolve(ROOT, "var", "sessions")

const log = ({
  level,
  msg,
}: {
  level: "debug" | "info" | "error"
  msg: string
}): void => {
  console.error(`[${level}] ${msg}`)
}

const measure = (label: string): Disposable => {
  const procT0 = performance.now()
  log({ level: "debug", msg: `${label} started` })

  return {
    [Symbol.dispose]() {
      const elapsed = ((performance.now() - procT0) / 1000).toFixed(2)
      log({ level: "info", msg: `${label} completed in ${elapsed}s` })
    },
  }
}

const gitUserName = (): Promise<string> =>
  promisify(execFile)("git", ["config", "user.name"])
    .then(({ stdout }) => stdout.trim())
    .catch(() => "")

const conf = (): Conf | undefined => {
  const [auth, host] = [env["LANGFUSE_AUTH"], env["LANGFUSE_BASE_URL"]]

  if (!auth || !host) {
    return undefined
  }

  return { auth, host }
}

const hookInput = async (): Promise<HookInput | undefined> => {
  const data = await text(stdin)
  return data.trim() ? (JSON.parse(data) as HookInput) : undefined
}

const openState = async (
  key: string,
): Promise<AsyncDisposable & { uuid?: string }> => {
  const path = resolve(SESSIONS_DIR, `${key}.openinference.uuid`)
  const uuid =
    (await readFile(path, "utf-8").catch(() => "")).trim() || undefined

  const state = {
    uuid,
    async [Symbol.asyncDispose]() {
      const tmp = `${path}.tmp`
      await mkdir(dirname(path), { recursive: true })
      await writeFile(tmp, state.uuid ?? "", "utf-8")
      await rename(tmp, path)
    },
  }
  return state
}

const provider = (
  config: Conf,
): AsyncDisposable & { provider: BasicTracerProvider } => {
  const exporter = new OTLPTraceExporter({
    url: join(config.host, `/api/public/otel/v1/traces`),
    headers: { Authorization: `Basic ${config.auth}` },
    timeoutMillis: 10_000,
  })
  const processor = new SimpleSpanProcessor(exporter)
  const provider = new BasicTracerProvider({ spanProcessors: [processor] })

  return {
    provider,
    async [Symbol.asyncDispose]() {
      await provider.shutdown()
    },
  }
}

const contents = function* ({
  message,
}: TranscriptMessage): IteratorObject<MessageBlock> {
  if (!message || typeof message !== "object") {
    return
  }

  const content = message.content
  if (typeof content === "string") {
    yield content
  } else if (Array.isArray(content)) {
    yield* content
  }

  return
}

const documentValue = (doc: BetaDocumentBlock | BetaRequestDocumentBlock) => {
  const context = "context" in doc ? doc.context : undefined
  switch (doc.source.type) {
    case "base64":
    case "text":
      return { context, media_type: doc.source.media_type, title: doc.title }
    case "url":
      return { context, title: doc.title, url: doc.source.url }
    case "content":
      return { context, title: doc.title }
    case "file":
      return { context, file_id: doc.source.file_id, title: doc.title }
    default:
      fail(doc.source satisfies never)
  }
}

const extractBlock = (
  role: SessionMessage["type"],
  block: MessageBlock,
): ExtractedBlock | undefined => {
  const side =
    role === "assistant"
      ? SemanticConventions.OUTPUT_VALUE
      : SemanticConventions.INPUT_VALUE

  if (typeof block === "string") {
    return {
      category: "text",
      type: side,
      kind: OpenInferenceSpanKind.LLM,
      value: block,
    }
  }

  switch (block.type) {
    case "text":
      return {
        category: "text",
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.citations?.length
          ? { text: block.text, citations: block.citations }
          : block.text,
      }
    case "thinking":
      if (!block.thinking) {
        return undefined
      }
      return {
        category: "text",
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.thinking,
      }
    case "redacted_thinking":
      return {
        category: "text",
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.data,
      }
    case "compaction":
      if (!block.content) {
        return undefined
      }
      return {
        category: "text",
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.content,
      }
    case "image":
      switch (block.source.type) {
        case "base64":
          return {
            category: "text",
            type: side,
            kind: OpenInferenceSpanKind.LLM,
            value: { media_type: block.source.media_type },
          }
        case "url":
          return {
            category: "text",
            type: side,
            kind: OpenInferenceSpanKind.LLM,
            value: { url: block.source.url },
          }
        case "file":
          return {
            category: "text",
            type: side,
            kind: OpenInferenceSpanKind.LLM,
            value: { file_id: block.source.file_id },
          }
        default:
          fail(block.source satisfies never)
      }

    case "mcp_tool_use":
      return {
        category: "tool",
        type: SemanticConventions.INPUT_VALUE,
        kind: OpenInferenceSpanKind.TOOL,
        correlationId: block.id,
        value: {
          name: block.name,
          input: block.input,
          server_name: block.server_name,
        },
      }
    case "server_tool_use":
    case "tool_use":
      return {
        category: "tool",
        type: SemanticConventions.INPUT_VALUE,
        kind: OpenInferenceSpanKind.TOOL,
        correlationId: block.id,
        value: { name: block.name, input: block.input },
      }

    case "tool_result":
    case "mcp_tool_result": {
      const value = (() => {
        const { content } = block
        if (content === undefined || typeof content === "string") {
          return content
        }
        return content.map((item) => {
          switch (item.type) {
            case "text":
              return item.text
            case "image":
              switch (item.source.type) {
                case "base64":
                  return { media_type: item.source.media_type }
                case "url":
                  return { url: item.source.url }
                case "file":
                  return { file_id: item.source.file_id }
                default:
                  fail(item.source satisfies never)
              }
            case "document":
              switch (item.source.type) {
                case "base64":
                case "text":
                  return {
                    context: item.context,
                    media_type: item.source.media_type,
                    title: item.title,
                  }
                case "url":
                  return {
                    context: item.context,
                    title: item.title,
                    url: item.source.url,
                  }
                case "content":
                  return { context: item.context, title: item.title }
                case "file":
                  return {
                    context: item.context,
                    file_id: item.source.file_id,
                    title: item.title,
                  }
                default:
                  fail(item.source satisfies never)
              }
            case "search_result":
              return { source: item.source, title: item.title }
            case "tool_reference":
              return item.tool_name
            default:
              fail(item satisfies never)
          }
        })
      })()
      return {
        category: "tool",
        type: SemanticConventions.OUTPUT_VALUE,
        error: block.is_error,
        kind: OpenInferenceSpanKind.TOOL,
        correlationId: block.tool_use_id,
        value,
      }
    }

    case "code_execution_tool_result":
    case "bash_code_execution_tool_result":
      switch (block.content.type) {
        case "bash_code_execution_tool_result_error":
        case "code_execution_tool_result_error":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            error: true,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: block.content.error_code,
          }
        case "encrypted_code_execution_result":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
            },
          }
        case "bash_code_execution_result":
        case "code_execution_result":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
              stdout: block.content.stdout,
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "text_editor_code_execution_tool_result":
      switch (block.content.type) {
        case "text_editor_code_execution_tool_result_error":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            error: true,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: {
              error_code: block.content.error_code,
              error_message: block.content.error_message,
            },
          }
        case "text_editor_code_execution_view_result":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: {
              content: block.content.content,
              file_type: block.content.file_type,
              num_lines: block.content.num_lines,
              start_line: block.content.start_line,
              total_lines: block.content.total_lines,
            },
          }
        case "text_editor_code_execution_create_result":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: { is_file_update: block.content.is_file_update },
          }
        case "text_editor_code_execution_str_replace_result":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: {
              lines: block.content.lines,
              new_lines: block.content.new_lines,
              new_start: block.content.new_start,
              old_lines: block.content.old_lines,
              old_start: block.content.old_start,
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "tool_search_tool_result":
      switch (block.content.type) {
        case "tool_search_tool_result_error": {
          const { type: _, ...rest } = block.content
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            error: true,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: rest,
          }
        }
        case "tool_search_tool_search_result":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: block.content.tool_references,
          }
        default:
          fail(block.content satisfies never)
      }

    case "document":
      return {
        category: "text",
        type: side,
        kind: OpenInferenceSpanKind.RETRIEVER,
        value: documentValue(block),
      }
    case "search_result":
      return {
        category: "text",
        type: side,
        kind: OpenInferenceSpanKind.RETRIEVER,
        value: {
          content: block.content.map((item) => item.text),
          source: block.source,
          title: block.title,
        },
      }
    case "web_search_tool_result":
      if (Array.isArray(block.content)) {
        return {
          category: "tool",
          type: SemanticConventions.OUTPUT_VALUE,
          kind: OpenInferenceSpanKind.RETRIEVER,
          correlationId: block.tool_use_id,
          value: block.content.map((r) => ({
            page_age: r.page_age,
            title: r.title,
            url: r.url,
          })),
        }
      }
      return {
        category: "tool",
        type: SemanticConventions.OUTPUT_VALUE,
        error: true,
        kind: OpenInferenceSpanKind.RETRIEVER,
        correlationId: block.tool_use_id,
        value: block.content.error_code,
      }
    case "web_fetch_tool_result":
      switch (block.content.type) {
        case "web_fetch_tool_result_error":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            error: true,
            kind: OpenInferenceSpanKind.RETRIEVER,
            correlationId: block.tool_use_id,
            value: block.content.error_code,
          }
        case "web_fetch_result":
          return {
            category: "tool",
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.RETRIEVER,
            correlationId: block.tool_use_id,
            value: {
              retrieved_at: block.content.retrieved_at,
              url: block.content.url,
              content: documentValue(block.content.content),
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "container_upload":
      return {
        category: "tool",
        type: side,
        kind: OpenInferenceSpanKind.TOOL,
        correlationId: undefined,
        value: { file_id: block.file_id },
      }

    default:
      fail(block satisfies never)
  }
}

const extractContent = function* (
  messages: IteratorObject<TranscriptMessage>,
): IteratorObject<SourcedBlock> {
  for (const message of messages) {
    for (const block of contents(message)) {
      const extracted = extractBlock(message.type, block)
      if (extracted) {
        yield [message, extracted]
      }
    }
  }

  return
}

const correlateToolCalls = function* (
  extracted: IteratorObject<SourcedBlock>,
): IteratorObject<Correlated> {
  const entries = extracted.toArray()

  const acc = new Map<string | undefined, SourcedBlock>()
  for (const entry of entries) {
    const [, block] = entry
    if (
      block.category === "tool" &&
      block.type === SemanticConventions.OUTPUT_VALUE &&
      block.correlationId
    ) {
      acc.set(block.correlationId, entry)
    }
  }

  for (const entry of entries) {
    const [, block] = entry
    if (block.category !== "tool") {
      yield [entry, undefined]
      continue
    }

    const id = block.correlationId
    if (block.type === SemanticConventions.OUTPUT_VALUE) {
      if (acc.delete(id)) {
        yield [entry, undefined]
      }
      continue
    }

    const mate = acc.get(id)
    if (mate === undefined) {
      yield [entry, undefined]
      continue
    }
    acc.delete(id)
    yield [entry, mate]
  }

  return
}

const emitSpans = ({
  tracer,
  userId,
  correlated,
  prev,
}: {
  tracer: Tracer
  userId: string
  correlated: Correlated
  prev?: Link
}): Link => {
  const [[message, { kind }], [endMessage] = []] = correlated

  const attributes = {
    [SemanticConventions.USER_ID]: userId,
    [SemanticConventions.SESSION_ID]: message.session_id,
    [SemanticConventions.TAG_TAGS]: ["claude-code"],
    "langfuse.observation.metadata.transcript_jq": message[META].debugExpr,
  }
  const span = tracer.startSpan(`[${message.session_id}] ${message.type}`, {
    startTime: message[META].timestamp.getTime(),
    attributes,
    links: prev ? [prev] : [],
  })

  if (
    correlated.some((pair) => {
      const [, block] = pair ?? []
      return block?.category === "tool" && block.error
    })
  ) {
    span.setStatus({ code: SpanStatusCode.ERROR })
  }

  span.setAttribute(SemanticConventions.OPENINFERENCE_SPAN_KIND, kind)

  for (const pair of correlated) {
    if (!pair) {
      continue
    }
    const [, block] = pair

    const mimeKey =
      block.type === SemanticConventions.INPUT_VALUE
        ? SemanticConventions.INPUT_MIME_TYPE
        : SemanticConventions.OUTPUT_MIME_TYPE

    span.setAttributes({
      [mimeKey]: MimeType.JSON,
      [block.type]: JSON.stringify(block.value),
    })
  }

  span.end(endMessage?.[META].timestamp)
  return { context: span.spanContext() }
}

const parseMessages = async function* (
  hook: HookInput,
  lastUuid: string | undefined,
): AsyncIteratorObject<TranscriptMessage> {
  const isSubAgent = hook.hook_event_name === "SubagentStop"
  const transcriptPath = isSubAgent
    ? hook.agent_transcript_path
    : hook.transcript_path

  const messages = (await (isSubAgent
    ? getSubagentMessages(hook.session_id, hook.agent_id)
    : getSessionMessages(hook.session_id))) as TranscriptMessage[]

  const foundIdx =
    lastUuid === undefined ? -1 : messages.findIndex((m) => m.uuid === lastUuid)
  const startIdx = foundIdx + 1

  log({
    level: "debug",
    msg: `messages: ${messages.length}, startIdx: ${startIdx}, found: ${foundIdx >= 0}`,
  })

  for (const message of messages.values().drop(startIdx)) {
    const meta = {
      timestamp: new Date(message.timestamp),
      debugExpr: `jq -e --sort-keys 'select(.uuid == "${message.uuid}")' '${transcriptPath}'`,
    } satisfies TranscriptMeta

    yield Object.assign(message, { [META]: meta })
  }

  return
}

const main = async (): Promise<void> => {
  const config = conf()
  if (!config) {
    return
  }

  const hook = await hookInput()
  if (!hook) {
    return
  }

  using _ = measure(`${hook.hook_event_name} (session=${hook.session_id})`)

  const stateKey =
    hook.hook_event_name === "SubagentStop"
      ? `${hook.session_id}.${hook.agent_id}`
      : hook.session_id

  await using state = await openState(stateKey)
  const transcriptRows = await Array.fromAsync(parseMessages(hook, state.uuid))

  const blocks = correlateToolCalls(extractContent(transcriptRows.values()))

  const userId = await gitUserName()
  await using otel = provider(config)
  const tracer = otel.provider.getTracer("langfuse-sdk")

  let prev: Link | undefined
  for (const correlated of blocks) {
    prev = emitSpans({ tracer, userId, correlated, prev })
  }

  state.uuid = transcriptRows.at(-1)?.uuid
}

await main()
