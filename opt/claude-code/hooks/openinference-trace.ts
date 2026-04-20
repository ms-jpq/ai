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
import type { Attributes, Context, Span, Tracer } from "@opentelemetry/api"
import { ROOT_CONTEXT, SpanStatusCode, trace } from "@opentelemetry/api"
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-proto"
import { resourceFromAttributes } from "@opentelemetry/resources"
import {
  BasicTracerProvider,
  BatchSpanProcessor,
} from "@opentelemetry/sdk-trace-base"
import {
  ATTR_SERVICE_INSTANCE_ID,
  ATTR_SERVICE_NAME,
} from "@opentelemetry/semantic-conventions"
import { fail } from "node:assert/strict"
import { execFile } from "node:child_process"
import { randomUUID } from "node:crypto"
import { mkdir, readFile, rename, writeFile } from "node:fs/promises"
import { dirname, resolve } from "node:path"
import { env, stdin } from "node:process"
import { text } from "node:stream/consumers"
import { fileURLToPath } from "node:url"
import { promisify } from "node:util"

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
  | (BaseExtractedBlock & { category: "user-text" })
  | (BaseExtractedBlock & { category: "agent-text" })
  | (BaseExtractedBlock & { category: "agent-thinking" })
  | (BaseExtractedBlock & {
      category: "tool"
      correlationId: string | undefined
      error?: boolean
    })

type BlockType = "string" | (BetaContentBlock | BetaContentBlockParam)["type"]

type SourcedBlock = readonly [
  TranscriptMessage,
  ExtractedBlock & { [META]: { block: BlockType } },
]

type AtomicGroup = {
  type: "correlated"
  orphaned?: "tool_use" | "tool_result"
  correlated: readonly [SourcedBlock, ...SourcedBlock[]]
}

type Grouped = Readonly<
  | {
      type: "grouped"
      kind: OpenInferenceSpanKind
      children: readonly Grouped[]
    }
  | AtomicGroup
>

type MessageBlock = string | BetaContentBlock | BetaContentBlockParam

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..")
const SESSIONS_DIR = resolve(ROOT, "var", "sessions")

const hookInput = async (): Promise<HookInput> =>
  JSON.parse(await text(stdin)) as HookInput

const gitUserName = (): Promise<string> =>
  promisify(execFile)("git", ["config", "user.name"])
    .then(({ stdout }) => stdout.trim())
    .catch(() => "")

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

const openState = async (
  hook: HookInput,
): Promise<AsyncDisposable & { uuid?: string }> => {
  const key =
    hook.hook_event_name === "SubagentStop"
      ? `${hook.session_id}.${hook.agent_id}`
      : hook.session_id
  const path = resolve(SESSIONS_DIR, `${key}.openinference.uuid`)

  const uuid =
    (await readFile(path, "utf-8").catch(() => "")).trim() || undefined

  const state = {
    uuid,
    async [Symbol.asyncDispose]() {
      const tmp = `${path}.${randomUUID()}.tmp`
      await mkdir(dirname(path), { recursive: true })
      await writeFile(tmp, state.uuid ?? "", "utf-8")
      await rename(tmp, path)
    },
  }
  return state
}

const provider = (
  hook: HookInput,
): (AsyncDisposable & { provider: BasicTracerProvider }) | undefined => {
  const [auth, url] = [env["LANGFUSE_AUTH"], env["LANGFUSE_TRACE_URL"]]
  if (!auth || !url) {
    return undefined
  }

  const provider = new BasicTracerProvider({
    resource: resourceFromAttributes({
      [ATTR_SERVICE_INSTANCE_ID]: hook.session_id,
      [ATTR_SERVICE_NAME]: "claude-code",
    }),
    spanProcessors: [
      new BatchSpanProcessor(
        new OTLPTraceExporter({
          url,
          headers: { Authorization: auth },
          timeoutMillis: 10_000,
        }),
        {
          maxQueueSize: 1_000_000,
        },
      ),
    ],
  })

  return {
    provider,
    async [Symbol.asyncDispose]() {
      await provider.shutdown()
    },
  }
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

  if (lastUuid !== undefined && foundIdx < 0) {
    log({
      level: "info",
      msg: `lastUuid ${lastUuid} not in transcript — treating as caught up`,
    })
    return
  }

  log({
    level: "debug",
    msg: `messages: ${messages.length}, startIdx: ${startIdx}`,
  })

  for (const message of messages.values().drop(startIdx)) {
    yield {
      ...message,
      [META]: {
        timestamp: new Date(message.timestamp),
        debugExpr: `jq -e --sort-keys 'select(.uuid == "${message.uuid}")' '${transcriptPath}'`,
      } satisfies TranscriptMeta,
    }
  }

  return
}

const correlateToolCalls = function* (
  extracted: IteratorObject<SourcedBlock>,
): IteratorObject<Grouped> {
  const acc = new Map<string, SourcedBlock>()

  for (const entry of extracted) {
    const [, block] = entry

    if (block.category !== "tool" || block.correlationId === undefined) {
      yield { type: "correlated", correlated: [entry] }
      continue
    }

    const id = block.correlationId
    if (block.type === SemanticConventions.INPUT_VALUE) {
      acc.set(id, entry)
      continue
    }

    const mate = acc.get(id)
    if (mate === undefined) {
      yield { type: "correlated", orphaned: "tool_result", correlated: [entry] }
      continue
    }
    acc.delete(id)
    yield { type: "correlated", correlated: [mate, entry] }
  }

  for (const entry of acc.values()) {
    yield { type: "correlated", orphaned: "tool_use", correlated: [entry] }
  }

  return
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

const documentValue = ({
  source,
  context,
  title,
}:
  | (BetaDocumentBlock & { context?: undefined })
  | BetaRequestDocumentBlock) => {
  switch (source.type) {
    case "base64":
    case "text":
      return { context, media_type: source.media_type, title }
    case "url":
      return { context, title, url: source.url }
    case "content":
      return { context, title }
    case "file":
      return { context, file_id: source.file_id, title }
    default:
      fail(source satisfies never)
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
  const textCategory = role === "assistant" ? "agent-text" : "user-text"

  if (typeof block === "string") {
    return {
      category: textCategory,
      type: side,
      kind: OpenInferenceSpanKind.LLM,
      value: block,
    }
  }

  switch (block.type) {
    case "text":
      return {
        category: textCategory,
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
        category: "agent-thinking",
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.thinking,
      }
    case "redacted_thinking":
      if (!block.data) {
        return undefined
      }
      return {
        category: "agent-thinking",
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.data,
      }
    case "compaction":
      if (!block.content) {
        return undefined
      }
      return {
        category: textCategory,
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.content,
      }
    case "image":
      switch (block.source.type) {
        case "base64":
          return {
            category: textCategory,
            type: side,
            kind: OpenInferenceSpanKind.LLM,
            value: { media_type: block.source.media_type },
          }
        case "url":
          return {
            category: textCategory,
            type: side,
            kind: OpenInferenceSpanKind.LLM,
            value: { url: block.source.url },
          }
        case "file":
          return {
            category: textCategory,
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
        category: textCategory,
        type: side,
        kind: OpenInferenceSpanKind.RETRIEVER,
        value: documentValue(block),
      }
    case "search_result":
      return {
        category: textCategory,
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
        const blockType = typeof block === "string" ? "string" : block.type
        yield [message, { ...extracted, [META]: { block: blockType } }]
      }
    }
  }

  return
}

const iterGrouped = function* (grouped: Grouped): IteratorObject<SourcedBlock> {
  switch (grouped.type) {
    case "correlated":
      yield* grouped.correlated
      return
    case "grouped":
      for (const child of grouped.children) {
        yield* iterGrouped(child)
      }
      return
    default:
      fail(grouped satisfies never)
  }
}

const groupBuffer = (kind: OpenInferenceSpanKind) => {
  const acc = new Array<Grouped>()
  return {
    push: (...group: Grouped[]) => acc.push(...group),
    pop: function* (flatten = false): IteratorObject<Grouped> {
      if (acc.length) {
        if (acc.length === 1 || flatten) {
          yield* acc
        } else {
          yield {
            type: "grouped",
            kind,
            children: [...acc],
          }
        }
      }
      acc.length = 0
      return
    },
  }
}

const generationId = (grouped: Grouped): string | undefined => {
  for (const [msg] of iterGrouped(grouped)) {
    if ("id" in msg.message) {
      return msg.message.id
    }
  }

  return undefined
}

const groupByGeneration = function* (
  entries: IteratorObject<Grouped>,
): IteratorObject<Grouped> {
  type Tagged = { genId: string | undefined; entry: Grouped }
  const tagged = entries
    .map((entry) => ({ genId: generationId(entry), entry }) satisfies Tagged)
    .toArray()

  const buckets = Map.groupBy(
    tagged.filter((t) => t.genId !== undefined),
    ({ genId }) => genId,
  )

  const seen = new Set<string>()
  for (const { genId, entry } of tagged) {
    if (genId === undefined) {
      yield entry
      continue
    }
    if (seen.has(genId)) {
      continue
    }
    seen.add(genId)

    const children = (buckets.get(genId) ?? []).map((c) => c.entry)
    if (children.length === 1) {
      yield* children
      continue
    }
    yield {
      type: "grouped",
      kind: OpenInferenceSpanKind.LLM,
      children,
    }
  }

  return
}

const isTurnStart = (entry: Grouped): boolean => {
  if (entry.type !== "correlated") {
    return false
  }
  const [[msg, block]] = entry.correlated
  return msg.type === "user" && block.category !== "tool"
}

const groupTurns = function* (
  entries: IteratorObject<Grouped>,
): IteratorObject<Grouped> {
  const acc = groupBuffer(OpenInferenceSpanKind.CHAIN)

  for (const entry of entries) {
    if (isTurnStart(entry)) {
      yield* acc.pop()
    }
    acc.push(entry)
  }
  yield* acc.pop()
  return
}

const groupChains = function* (
  hook: HookInput,
  entries: IteratorObject<Grouped>,
): IteratorObject<Grouped> {
  if (hook.hook_event_name === "SubagentStop") {
    yield {
      type: "grouped",
      kind: OpenInferenceSpanKind.CHAIN,
      children: entries.toArray(),
    }
    return
  }

  yield* groupTurns(entries)
  return
}

const attachIO = ({
  span,
  grouped,
  sourceBlocks = iterGrouped(grouped).toArray(),
}: {
  span: Span
  grouped: Grouped
  sourceBlocks?: readonly SourcedBlock[]
}) => {
  const output = sourceBlocks.findLast(
    ([, block]) => block.type === SemanticConventions.OUTPUT_VALUE,
  )
  const [, lastOutputBlock] = output ?? []

  if (lastOutputBlock) {
    span.setAttributes({
      [SemanticConventions.OUTPUT_MIME_TYPE]: MimeType.JSON,
      [SemanticConventions.OUTPUT_VALUE]: JSON.stringify(lastOutputBlock.value),
    })
  }

  const lastCorrelationId =
    lastOutputBlock?.category === "tool"
      ? lastOutputBlock.correlationId
      : undefined
  const [_, firstInputBlock] =
    sourceBlocks.find(([, block]) => {
      if (block.category === "tool") {
        return block.correlationId === lastCorrelationId
      }

      if (block.type === SemanticConventions.INPUT_VALUE) {
        return block !== lastOutputBlock
      }

      if (block.category === "agent-text") {
        return true
      }

      return false
    }) ?? []

  if (firstInputBlock) {
    span.setAttributes({
      [SemanticConventions.INPUT_MIME_TYPE]: MimeType.JSON,
      [SemanticConventions.INPUT_VALUE]: JSON.stringify(firstInputBlock.value),
    })
  }
}

const emitCorrelated = ({
  tracer,
  parentCtx,
  sharedAttributes,
  grouped,
  startTime,
  endTime,
}: {
  tracer: Tracer
  parentCtx: Context
  sharedAttributes: Attributes
  grouped: AtomicGroup
  startTime: number
  endTime: number
}) => {
  const [[startMsg, { kind }]] = grouped.correlated
  const span = tracer.startSpan(
    startMsg.type,
    {
      startTime,
      attributes: {
        ...sharedAttributes,
        [SemanticConventions.OPENINFERENCE_SPAN_KIND]: kind,
        "langfuse.observation.metadata.transcript_jq": startMsg[META].debugExpr,
        "langfuse.observation.metadata.block_types": grouped.correlated.map(
          ([, block]) => block[META].block,
        ),
        ...(grouped.orphaned
          ? { "langfuse.observation.metadata.orphaned": grouped.orphaned }
          : {}),
      },
    },
    parentCtx,
  )

  if (
    grouped.correlated.some(
      ([, block]) => block.category === "tool" && block.error,
    )
  ) {
    span.setStatus({ code: SpanStatusCode.ERROR })
  }

  attachIO({ span, grouped })
  span.end(endTime)
}

const emitGrouped = ({
  tracer,
  parentCtx,
  userId,
  sessionId,
  grouped,
}: {
  tracer: Tracer
  parentCtx: Context
  userId: string
  sessionId: string
  grouped: Grouped
}): void => {
  const flattened = iterGrouped(grouped).toArray()
  const times = flattened.map(([m]) => m[META].timestamp.getTime())
  if (!times.length) {
    return
  }

  const startTime = Math.min(...times)
  const endTime = Math.max(...times)
  const sharedAttributes = {
    [SemanticConventions.USER_ID]: userId,
    [SemanticConventions.SESSION_ID]: sessionId,
  }

  if (grouped.type === "correlated") {
    emitCorrelated({
      tracer,
      parentCtx,
      sharedAttributes,
      grouped,
      startTime,
      endTime,
    })
    return
  }

  const span = tracer.startSpan(
    grouped.kind,
    {
      startTime,
      attributes: {
        ...sharedAttributes,
        [SemanticConventions.OPENINFERENCE_SPAN_KIND]: grouped.kind,
      },
    },
    parentCtx,
  )

  const childCtx = trace.setSpan(parentCtx, span)
  for (const child of grouped.children) {
    emitGrouped({
      tracer,
      parentCtx: childCtx,
      userId,
      sessionId,
      grouped: child,
    })
  }

  attachIO({ span, grouped, sourceBlocks: flattened })
  span.end(endTime)
  return
}

const main = async (): Promise<void> => {
  const [hook, userId] = await Promise.all([hookInput(), gitUserName()])
  using _ = measure(`${hook.hook_event_name} (session=${hook.session_id})`)

  await using state = await openState(hook)
  await using otel = provider(hook)
  if (!otel) {
    return
  }

  const transcriptRows = await Array.fromAsync(parseMessages(hook, state.uuid))
  const correlated = correlateToolCalls(extractContent(transcriptRows.values()))
  const generations = groupByGeneration(correlated)
  const grouped = groupChains(hook, generations)

  const tracer = otel.provider.getTracer("langfuse-sdk")
  for (const group of grouped) {
    emitGrouped({
      tracer,
      parentCtx: ROOT_CONTEXT,
      userId,
      sessionId: hook.session_id,
      grouped: group,
    })
  }

  await otel.provider.forceFlush()
  if (hook.hook_event_name !== "SubagentStop") {
    const tailUuid = transcriptRows.at(-1)?.uuid
    if (tailUuid !== undefined) {
      state.uuid = tailUuid
    }
  }
}

await main()
