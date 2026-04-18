#!/usr/bin/env -S -- node

import type { HookInput, SessionMessage } from "@anthropic-ai/claude-agent-sdk"
import {
  getSessionMessages,
  getSubagentMessages,
} from "@anthropic-ai/claude-agent-sdk"
import type {
  BetaContentBlock,
  BetaContentBlockParam,
  BetaMessage,
  BetaMessageParam,
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
import { fail, ok } from "node:assert/strict"
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
  offset: number
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

type ExtractedBlock = Readonly<{
  type:
    | typeof SemanticConventions.INPUT_VALUE
    | typeof SemanticConventions.OUTPUT_VALUE
  error?: boolean
  kind: OpenInferenceSpanKind
  value: unknown
  correlationId?: string
  transcriptJq?: string
}>

type CorrelatedBlock = readonly [ExtractedBlock, ExtractedBlock]

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..")
const SESSIONS_DIR = resolve(ROOT, "var", "sessions")

const log = ({
  level,
  msg,
}: {
  level: "debug" | "info" | "error"
  msg: string
}): void => {
  if (level === "error") {
    console.error(`[${level}] ${msg}`)
  }
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
): Promise<AsyncDisposable & { offset: number }> => {
  const path = resolve(SESSIONS_DIR, `${key}.langfuse.json`)
  const state = await (async () => {
    try {
      const offset = Number(await readFile(path, "utf-8"))
      ok(Number.isInteger(offset))
      return { offset }
    } catch {
      return { offset: 0 }
    }
  })()

  return Object.assign(state, {
    async [Symbol.asyncDispose]() {
      const tmp = `${path}.tmp`
      await mkdir(dirname(path), { recursive: true })
      await writeFile(tmp, String(state.offset), "utf-8")
      await rename(tmp, path)
    },
  })
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

const extractBlock = (
  role: SessionMessage["type"],
  block: MessageBlock,
): ExtractedBlock => {
  const side =
    role === "assistant"
      ? SemanticConventions.OUTPUT_VALUE
      : SemanticConventions.INPUT_VALUE

  if (typeof block === "string") {
    return { type: side, kind: OpenInferenceSpanKind.LLM, value: block }
  }

  switch (block.type) {
    case "text":
      return { type: side, kind: OpenInferenceSpanKind.LLM, value: block.text }
    case "thinking":
      return {
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.thinking,
      }
    case "redacted_thinking":
      return {
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.data,
      }
    case "compaction":
      return {
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.content ?? "",
      }
    case "image":
      switch (block.source.type) {
        case "base64":
          return {
            type: side,
            kind: OpenInferenceSpanKind.LLM,
            value: { media_type: block.source.media_type },
          }
        case "url":
          return {
            type: side,
            kind: OpenInferenceSpanKind.LLM,
            value: { url: block.source.url },
          }
        case "file":
          return {
            type: side,
            kind: OpenInferenceSpanKind.LLM,
            value: { file_id: block.source.file_id },
          }
        default:
          fail(block.source satisfies never)
      }

    case "mcp_tool_use":
      return {
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
            type: SemanticConventions.OUTPUT_VALUE,
            error: true,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: block.content.error_code,
          }
        case "encrypted_code_execution_result":
          return {
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
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: { is_file_update: block.content.is_file_update },
          }
        case "text_editor_code_execution_str_replace_result":
          return {
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
            type: SemanticConventions.OUTPUT_VALUE,
            error: true,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: rest,
          }
        }
        case "tool_search_tool_search_result":
          return {
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.TOOL,
            correlationId: block.tool_use_id,
            value: block.content.tool_references,
          }
        default:
          fail(block.content satisfies never)
      }

    case "document":
      switch (block.source.type) {
        case "base64":
        case "text":
          return {
            type: side,
            kind: OpenInferenceSpanKind.RETRIEVER,
            value: {
              context: block.context,
              media_type: block.source.media_type,
              title: block.title,
            },
          }
        case "url":
          return {
            type: side,
            kind: OpenInferenceSpanKind.RETRIEVER,
            value: {
              context: block.context,
              title: block.title,
              url: block.source.url,
            },
          }
        case "content":
          return {
            type: side,
            kind: OpenInferenceSpanKind.RETRIEVER,
            value: { context: block.context, title: block.title },
          }
        case "file":
          return {
            type: side,
            kind: OpenInferenceSpanKind.RETRIEVER,
            value: {
              context: block.context,
              file_id: block.source.file_id,
              title: block.title,
            },
          }
        default:
          fail(block.source satisfies never)
      }
    case "search_result":
      return {
        type: SemanticConventions.OUTPUT_VALUE,
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
            type: SemanticConventions.OUTPUT_VALUE,
            error: true,
            kind: OpenInferenceSpanKind.RETRIEVER,
            correlationId: block.tool_use_id,
            value: block.content.error_code,
          }
        case "web_fetch_result":
          return {
            type: SemanticConventions.OUTPUT_VALUE,
            kind: OpenInferenceSpanKind.RETRIEVER,
            correlationId: block.tool_use_id,
            value: {
              retrieved_at: block.content.retrieved_at,
              url: block.content.url,
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "container_upload":
      return {
        type: side,
        kind: OpenInferenceSpanKind.TOOL,
        value: { file_id: block.file_id },
      }

    default:
      fail(block satisfies never)
  }
}

const extractContent = function* (
  messages: IteratorObject<TranscriptMessage>,
): IteratorObject<[TranscriptMessage, ExtractedBlock]> {
  for (const message of messages) {
    for (const block of contents(message)) {
      const extracted = extractBlock(message.type, block)
      yield [message, extracted]
    }
  }

  return
}

const correlatedBlocks = function* (
  extracted: IteratorObject<[TranscriptMessage, ExtractedBlock]>,
): IteratorObject<[TranscriptMessage, CorrelatedBlock | ExtractedBlock]> {
  const items = extracted.toArray()

  const acc = new Map<string, ExtractedBlock>()
  for (const [, block] of items) {
    if (
      block.correlationId !== undefined &&
      block.type === SemanticConventions.OUTPUT_VALUE
    ) {
      acc.set(block.correlationId, block)
    }
  }

  for (const [message, block] of items) {
    const id = block.correlationId
    if (id === undefined) {
      yield [message, block]
      continue
    }

    if (block.type === SemanticConventions.OUTPUT_VALUE) {
      if (acc.delete(id)) {
        yield [message, block]
      }
      continue
    }

    const mate = acc.get(id)
    if (mate === undefined) {
      yield [message, block]
      continue
    }
    acc.delete(id)
    yield [message, [block, mate]]
  }

  return
}

const emitSpans = ({
  tracer,
  userId,
  sessionId,
  message,
  block,
  prev,
}: {
  tracer: Tracer
  userId: string
  sessionId: string
  message: TranscriptMessage
  block: CorrelatedBlock | ExtractedBlock
  prev?: Link
}): Link => {
  const span = tracer.startSpan(`[${sessionId}] ${message.type}`, {
    startTime: message[META].timestamp.getTime(),
    attributes: {
      [SemanticConventions.USER_ID]: userId,
      [SemanticConventions.SESSION_ID]: sessionId,
      [SemanticConventions.TAG_TAGS]: ["claude-code"],
      "langfuse.observation.metadata.transcript_jq": message[META].debugExpr,
    },
    links: prev ? [prev] : [],
  })

  const parts = Array.isArray(block) ? block : [block]
  const [part] = parts

  if (parts.some((p) => p.error)) {
    span.setStatus({ code: SpanStatusCode.ERROR })
  }

  span.setAttribute(SemanticConventions.OPENINFERENCE_SPAN_KIND, part.kind)

  for (const part of parts) {
    const mimeKey =
      part.type === SemanticConventions.INPUT_VALUE
        ? SemanticConventions.INPUT_MIME_TYPE
        : SemanticConventions.OUTPUT_MIME_TYPE

    span.setAttributes({
      [mimeKey]: MimeType.JSON,
      [part.type]: JSON.stringify(part.value),
    })
  }

  span.end()
  return { context: span.spanContext() }
}

const parseMessages = async function* (
  hook: HookInput,
  offset: number,
): AsyncIteratorObject<TranscriptMessage> {
  const isSubAgent = hook.hook_event_name === "SubagentStop"
  const transcriptPath = isSubAgent
    ? hook.agent_transcript_path
    : hook.transcript_path

  const opts = { offset }
  const messages = (await (isSubAgent
    ? getSubagentMessages(hook.session_id, hook.agent_id, opts)
    : getSessionMessages(hook.session_id, opts))) as TranscriptMessage[]

  log({ level: "debug", msg: `messages: ${messages.length}` })

  for (const [i, msg] of messages.entries()) {
    const meta = {
      offset: offset + i,
      timestamp: new Date(msg.timestamp),
      debugExpr: `jq -e --sort-keys 'select(.uuid == "${msg.uuid}")' '${transcriptPath}'`,
    } satisfies TranscriptMeta

    yield Object.assign(msg, { [META]: meta })
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

  const isSub = hook.hook_event_name === "SubagentStop"
  const stateKey = isSub
    ? `${hook.session_id}.${hook.agent_id}`
    : hook.session_id

  const userId = await gitUserName()
  await using state = await openState(stateKey)

  const transcriptRows = await Array.fromAsync(
    parseMessages(hook, state.offset),
  )
  const messages = correlatedBlocks(extractContent(transcriptRows.values()))

  await using otel = provider(config)
  const tracer = otel.provider.getTracer("langfuse-sdk")
  let prev: Link | undefined
  for (const [message, block] of messages) {
    prev = emitSpans({
      tracer,
      userId,
      sessionId: hook.session_id,
      message,
      block,
      prev,
    })
  }

  state.offset += transcriptRows.length
}

await main()
