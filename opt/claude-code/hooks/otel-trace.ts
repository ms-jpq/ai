#!/usr/bin/env -S -- node

import type { HookInput, SDKMessage } from "@anthropic-ai/claude-agent-sdk"
import type {
  BetaContentBlock,
  BetaContentBlockParam,
  BetaDocumentBlock,
  BetaMessageParam,
  BetaRequestDocumentBlock,
} from "@anthropic-ai/sdk/resources/beta/messages/messages.js"
import type { Attributes, Context, Tracer } from "@opentelemetry/api"
import {
  ROOT_CONTEXT,
  SpanKind,
  SpanStatusCode,
  trace,
} from "@opentelemetry/api"
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-proto"
import {
  defaultResource,
  detectResources,
  hostDetector,
  osDetector,
  processDetector,
  resourceFromAttributes,
} from "@opentelemetry/resources"
import {
  BasicTracerProvider,
  BatchSpanProcessor,
} from "@opentelemetry/sdk-trace-base"
import {
  ATTR_ERROR_TYPE,
  ATTR_SERVER_ADDRESS,
  ATTR_SERVICE_INSTANCE_ID,
  ATTR_SERVICE_NAME,
} from "@opentelemetry/semantic-conventions"
import {
  ATTR_GEN_AI_AGENT_ID,
  ATTR_GEN_AI_AGENT_NAME,
  ATTR_GEN_AI_CONVERSATION_ID,
  ATTR_GEN_AI_INPUT_MESSAGES,
  ATTR_GEN_AI_OPERATION_NAME,
  ATTR_GEN_AI_OUTPUT_MESSAGES,
  ATTR_GEN_AI_OUTPUT_TYPE,
  ATTR_GEN_AI_PROVIDER_NAME,
  ATTR_GEN_AI_REQUEST_MODEL,
  ATTR_GEN_AI_RESPONSE_FINISH_REASONS,
  ATTR_GEN_AI_RESPONSE_ID,
  ATTR_GEN_AI_RESPONSE_MODEL,
  ATTR_GEN_AI_TOOL_CALL_ARGUMENTS,
  ATTR_GEN_AI_TOOL_CALL_ID,
  ATTR_GEN_AI_TOOL_CALL_RESULT,
  ATTR_GEN_AI_TOOL_NAME,
  ATTR_GEN_AI_TOOL_TYPE,
  ATTR_GEN_AI_USAGE_CACHE_CREATION_INPUT_TOKENS,
  ATTR_GEN_AI_USAGE_CACHE_READ_INPUT_TOKENS,
  ATTR_GEN_AI_USAGE_INPUT_TOKENS,
  ATTR_GEN_AI_USAGE_OUTPUT_TOKENS,
  ATTR_USER_ID,
  GEN_AI_OPERATION_NAME_VALUE_CHAT,
  GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
  GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
  GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
  GEN_AI_OUTPUT_TYPE_VALUE_TEXT,
  GEN_AI_PROVIDER_NAME_VALUE_ANTHROPIC,
  GEN_AI_TOKEN_TYPE_VALUE_INPUT,
  GEN_AI_TOKEN_TYPE_VALUE_OUTPUT,
} from "@opentelemetry/semantic-conventions/incubating"
import { fail, ok } from "node:assert/strict"
import { execFile } from "node:child_process"
import { randomUUID } from "node:crypto"
import { createReadStream } from "node:fs"
import { mkdir, readFile, rename, writeFile } from "node:fs/promises"
import { dirname, resolve } from "node:path"
import { env, stdin } from "node:process"
import { createInterface } from "node:readline"
import { text } from "node:stream/consumers"
import { fileURLToPath } from "node:url"
import { promisify } from "node:util"

type NonEmpty<T> = readonly [T, ...T[]]

const isNonEmpty = <T>(arr: readonly T[]): arr is NonEmpty<T> => arr.length > 0

type TranscriptMeta = Readonly<{
  timestamp: Date
  debugExpr: string
}>

type MessageBlock = string | BetaContentBlock | BetaContentBlockParam

const META: unique symbol = Symbol("transcript-meta")
type TranscriptMessage = Readonly<
  Extract<SDKMessage, { type: BetaMessageParam["role"] }> & {
    timestamp: string
    [META]: TranscriptMeta
  }
>

type BlockKind =
  | typeof GEN_AI_OPERATION_NAME_VALUE_CHAT
  | typeof GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL
  | typeof GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL

type GroupedKind = BlockKind | typeof GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT

type ExtractedBlockType =
  | typeof GEN_AI_TOKEN_TYPE_VALUE_INPUT
  | typeof GEN_AI_TOKEN_TYPE_VALUE_OUTPUT

// Anthropic extends OTel's text/tool_call/tool_call_response with reasoning, blob, uri, file, document, search_result.
type ChatPart = Readonly<Record<string, unknown> & { type: string }>

type ExtractedBlock =
  | Readonly<{
      category: "chat"
      type: ExtractedBlockType
      part: ChatPart
    }>
  | Readonly<{
      category: "tool"
      type: ExtractedBlockType
      kind: BlockKind
      value: unknown
      correlationId: string | undefined
      toolName?: string
      toolType?: "function" | "extension"
      error?: string
    }>

type ToolBlock = Extract<ExtractedBlock, { category: "tool" }>

type SourcedToolBlock = Readonly<{
  msg: TranscriptMessage
  block: ToolBlock
}>

type Facts = Readonly<{
  model?: string
  responseId?: string
  stopReasons?: readonly string[]
  usage?: Readonly<{
    input_tokens: number
    output_tokens: number
    cache_read_input_tokens: number
    cache_creation_input_tokens: number
  }>
}>

type Grouped = Readonly<{
  spanName: string
  spanKind: SpanKind
  startTime: number
  endTime: number
  attributes: Attributes
  status?: { code: SpanStatusCode }
  children?: readonly Grouped[]
  turnStart?: boolean
}>

type Ctx = { userId: string; sessionId: string }

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..")
const SESSIONS_DIR = resolve(ROOT, "var", "sessions")

const hookInput = async (): Promise<HookInput> => JSON.parse(await text(stdin))

const gitUserName = (): Promise<string> =>
  promisify(execFile)("git", ["config", "user.name"])
    .then(({ stdout }) => stdout.trim())
    .catch(() => "")

const chunkBy = function* <T>({
  source,
  isBoundary,
}: {
  source: IteratorObject<T>
  isBoundary: (item: T) => boolean
}): IteratorObject<NonEmpty<T>> {
  let chunk = new Array<T>()
  for (const item of source) {
    if (isBoundary(item) && isNonEmpty(chunk)) {
      yield chunk
      chunk = []
    }
    chunk.push(item)
  }
  if (isNonEmpty(chunk)) {
    yield chunk
  }
  return
}

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
    resource: defaultResource()
      .merge(
        detectResources({
          detectors: [hostDetector, osDetector, processDetector],
        }),
      )
      .merge(
        resourceFromAttributes({
          [ATTR_SERVICE_INSTANCE_ID]: hook.session_id,
          [ATTR_SERVICE_NAME]: "claude-code",
        }),
      ),
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

const readJsonL = async function* (
  path: string,
): AsyncIteratorObject<TranscriptMessage> {
  const rl = createInterface({
    input: createReadStream(path, { encoding: "utf-8" }),
    crlfDelay: Infinity,
  })
  for await (const line of rl) {
    if (line) {
      yield JSON.parse(line)
    }
  }
  return
}

const parseMessages = async function* (
  hook: HookInput,
  lastUuid: string | undefined,
): AsyncIteratorObject<TranscriptMessage> {
  const isSubAgent = hook.hook_event_name === "SubagentStop"
  const transcriptPath = isSubAgent
    ? hook.agent_transcript_path
    : hook.transcript_path

  let found = lastUuid === undefined
  for await (const message of readJsonL(transcriptPath)) {
    if (!found) {
      found ||= message.uuid === lastUuid
      continue
    }
    if (message.type !== "user" && message.type !== "assistant") {
      continue
    }

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

const contents = function* (
  msg: TranscriptMessage,
): IteratorObject<MessageBlock> {
  const content = msg.message.content
  if (typeof content === "string") {
    yield content
  } else if (Array.isArray(content)) {
    yield* content
  }

  return
}

const extractChat = ({
  side,
  part,
}: {
  side: ExtractedBlock["type"]
  part: ChatPart
}) =>
  ({
    category: "chat",
    type: side,
    part,
  }) satisfies ExtractedBlock

const extractToolUse = ({
  toolName,
  toolType,
  correlationId,
  value,
}: {
  toolName: string
  toolType: "function" | "extension"
  correlationId: string
  value: unknown
}) =>
  ({
    category: "tool",
    type: GEN_AI_TOKEN_TYPE_VALUE_INPUT,
    kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
    correlationId,
    toolName,
    toolType,
    value,
  }) satisfies ExtractedBlock

const extractToolResult = ({
  correlationId,
  value,
  kind = GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
  error,
}: {
  correlationId: string
  value: unknown
  kind?: BlockKind
  error?: string
}) =>
  ({
    category: "tool",
    type: GEN_AI_TOKEN_TYPE_VALUE_OUTPUT,
    kind,
    correlationId,
    value,
    ...(error !== undefined ? { error } : {}),
  }) satisfies ExtractedBlock

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

const imageValue = ({
  source,
}: {
  source:
    | { type: "base64"; media_type: string }
    | { type: "url"; url: string }
    | { type: "file"; file_id: string }
}) => {
  switch (source.type) {
    case "base64":
      return { media_type: source.media_type }
    case "url":
      return { url: source.url }
    case "file":
      return { file_id: source.file_id }
    default:
      fail(source satisfies never)
  }
}

const imagePart = ({
  source,
}: {
  source:
    | { type: "base64"; media_type: string }
    | { type: "url"; url: string }
    | { type: "file"; file_id: string }
}): ChatPart => {
  switch (source.type) {
    case "base64":
      return {
        type: "blob",
        content: "",
        mime_type: source.media_type,
        modality: "image",
      }
    case "url":
      return { type: "uri", uri: source.url, modality: "image" }
    case "file":
      return { type: "file", file_id: source.file_id, modality: "image" }
    default:
      fail(source satisfies never)
  }
}

const documentPart = (
  block:
    | (BetaDocumentBlock & { context?: undefined })
    | BetaRequestDocumentBlock,
): ChatPart => {
  const { source } = block
  const meta = {
    ...(block.title ? { title: block.title } : {}),
    ...(block.context ? { context: block.context } : {}),
  }
  switch (source.type) {
    case "base64":
    case "text":
      return {
        type: "blob",
        content: "",
        mime_type: source.media_type,
        ...meta,
      }
    case "url":
      return { type: "uri", uri: source.url, ...meta }
    case "file":
      return { type: "file", file_id: source.file_id, ...meta }
    case "content":
      return { type: "document", ...meta }
    default:
      fail(source satisfies never)
  }
}

const extractBlock = (
  role: TranscriptMessage["type"],
  block: MessageBlock,
): ExtractedBlock | undefined => {
  const side =
    role === "assistant"
      ? GEN_AI_TOKEN_TYPE_VALUE_OUTPUT
      : GEN_AI_TOKEN_TYPE_VALUE_INPUT

  if (typeof block === "string") {
    return extractChat({ side, part: { type: "text", content: block } })
  }

  switch (block.type) {
    case "text":
      return extractChat({
        side,
        part: {
          type: "text",
          content: block.text,
          ...(block.citations?.length ? { citations: block.citations } : {}),
        },
      })
    case "thinking":
      return block.thinking
        ? extractChat({
            side,
            part: { type: "reasoning", content: block.thinking },
          })
        : undefined
    case "redacted_thinking":
      return block.data
        ? extractChat({
            side,
            part: { type: "reasoning", content: block.data },
          })
        : undefined
    case "compaction":
      return block.content
        ? extractChat({
            side,
            part: { type: "text", content: block.content },
          })
        : undefined
    case "image":
      return extractChat({ side, part: imagePart(block) })

    case "mcp_tool_use":
      return extractToolUse({
        toolName: `mcp__${block.server_name}__${block.name}`,
        toolType: "extension",
        correlationId: block.id,
        value: block.input,
      })
    case "server_tool_use":
      return extractToolUse({
        toolName: block.name,
        toolType: "extension",
        correlationId: block.id,
        value: block.input,
      })
    case "tool_use":
      return extractToolUse({
        toolName: block.name,
        toolType: "function",
        correlationId: block.id,
        value: block.input,
      })

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
              return imageValue(item)
            case "document":
              return documentValue(item)
            case "search_result":
              return { source: item.source, title: item.title }
            case "tool_reference":
              return item.tool_name
            default:
              fail(item satisfies never)
          }
        })
      })()
      return extractToolResult({
        correlationId: block.tool_use_id,
        value,
        error: block.is_error ? "_OTHER" : undefined,
      })
    }

    case "code_execution_tool_result":
    case "bash_code_execution_tool_result":
      switch (block.content.type) {
        case "bash_code_execution_tool_result_error":
        case "code_execution_tool_result_error":
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: block.content.error_code,
            error: block.content.error_code,
          })
        case "encrypted_code_execution_result":
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
            },
          })
        case "bash_code_execution_result":
        case "code_execution_result":
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
              stdout: block.content.stdout,
            },
          })
        default:
          fail(block.content satisfies never)
      }

    case "text_editor_code_execution_tool_result":
      switch (block.content.type) {
        case "text_editor_code_execution_tool_result_error":
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: {
              error_code: block.content.error_code,
              error_message: block.content.error_message,
            },
            error: block.content.error_code,
          })
        case "text_editor_code_execution_view_result":
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: {
              content: block.content.content,
              file_type: block.content.file_type,
              num_lines: block.content.num_lines,
              start_line: block.content.start_line,
              total_lines: block.content.total_lines,
            },
          })
        case "text_editor_code_execution_create_result":
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: { is_file_update: block.content.is_file_update },
          })
        case "text_editor_code_execution_str_replace_result":
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: {
              lines: block.content.lines,
              new_lines: block.content.new_lines,
              new_start: block.content.new_start,
              old_lines: block.content.old_lines,
              old_start: block.content.old_start,
            },
          })
        default:
          fail(block.content satisfies never)
      }

    case "tool_search_tool_result":
      switch (block.content.type) {
        case "tool_search_tool_result_error": {
          const { type: _, ...rest } = block.content
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: rest,
            error: block.content.error_code,
          })
        }
        case "tool_search_tool_search_result":
          return extractToolResult({
            correlationId: block.tool_use_id,
            value: block.content.tool_references,
          })
        default:
          fail(block.content satisfies never)
      }

    case "document":
      return extractChat({ side, part: documentPart(block) })
    case "search_result":
      return extractChat({
        side,
        part: {
          type: "search_result",
          content: block.content.map((item) => item.text),
          source: block.source,
          title: block.title,
        },
      })
    case "web_search_tool_result":
      if (Array.isArray(block.content)) {
        return extractToolResult({
          correlationId: block.tool_use_id,
          kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
          value: block.content.map((r) => ({
            page_age: r.page_age,
            title: r.title,
            url: r.url,
          })),
        })
      }
      return extractToolResult({
        correlationId: block.tool_use_id,
        kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
        value: block.content.error_code,
        error: block.content.error_code,
      })
    case "web_fetch_tool_result":
      switch (block.content.type) {
        case "web_fetch_tool_result_error":
          return extractToolResult({
            correlationId: block.tool_use_id,
            kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
            value: block.content.error_code,
            error: block.content.error_code,
          })
        case "web_fetch_result":
          return extractToolResult({
            correlationId: block.tool_use_id,
            kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
            value: {
              retrieved_at: block.content.retrieved_at,
              url: block.content.url,
              content: documentValue(block.content.content),
            },
          })
        default:
          fail(block.content satisfies never)
      }

    case "container_upload":
      return {
        category: "tool",
        type: side,
        kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
        correlationId: undefined,
        toolName: block.type,
        toolType: "extension",
        value: { file_id: block.file_id },
      } satisfies ExtractedBlock

    default:
      fail(block satisfies never)
  }
}

const blockToPart = (block: ExtractedBlock): ChatPart => {
  if (block.category === "chat") {
    return block.part
  }

  if (block.type === GEN_AI_TOKEN_TYPE_VALUE_INPUT) {
    return {
      type: "tool_call",
      id: block.correlationId,
      name: block.toolName,
      arguments: block.value,
    }
  }

  return {
    type: "tool_call_response",
    id: block.correlationId,
    response: block.value,
  }
}

const messageParts = function* (
  msg: TranscriptMessage,
): IteratorObject<ChatPart> {
  for (const raw of contents(msg)) {
    const extracted = extractBlock(msg.type, raw)
    if (extracted) {
      yield blockToPart(extracted)
    }
  }
  return
}

const normalizeFinishReason = (() => {
  const map = new Map<string, string>([
    ["end_turn", "stop"],
    ["stop_sequence", "stop"],
    ["max_tokens", "length"],
    ["tool_use", "tool_calls"],
    ["refusal", "content_filter"],
  ])
  return (raw: string | null | undefined) => map.get(raw ?? "") ?? raw ?? "stop"
})()

const transcriptToMessage = ({
  msg,
  asOutput,
}: {
  msg: TranscriptMessage
  asOutput: boolean
}) => ({
  role: msg.type,
  parts: messageParts(msg).toArray(),
  finish_reason:
    asOutput && msg.type === "assistant"
      ? normalizeFinishReason(msg.message.stop_reason)
      : undefined,
})

const factsFromAssistant = (
  msg: Extract<TranscriptMessage, { type: "assistant" }>,
): Facts => {
  if (msg.message.model === "<synthetic>") {
    return {
      stopReasons: msg.message.stop_reason ? [msg.message.stop_reason] : [],
    }
  }

  const u = msg.message.usage
  return {
    model: msg.message.model,
    responseId: msg.message.id,
    stopReasons: msg.message.stop_reason ? [msg.message.stop_reason] : [],
    usage: {
      // Total prompt size including cache reads/creations; cache_* attrs break it down.
      input_tokens:
        u.input_tokens +
        (u.cache_read_input_tokens ?? 0) +
        (u.cache_creation_input_tokens ?? 0),
      output_tokens: u.output_tokens,
      cache_read_input_tokens: u.cache_read_input_tokens ?? 0,
      cache_creation_input_tokens: u.cache_creation_input_tokens ?? 0,
    },
  }
}

const commonAttrs = ({
  kind,
  ctx,
  facts,
}: {
  kind: GroupedKind
  ctx: Ctx
  facts?: Facts
}): Attributes => {
  const { model, responseId, stopReasons, usage } = facts ?? {}
  const isApi =
    kind === GEN_AI_OPERATION_NAME_VALUE_CHAT ||
    kind === GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL
  const hasOutputType = kind !== GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL

  return {
    [ATTR_USER_ID]: ctx.userId,
    [ATTR_GEN_AI_CONVERSATION_ID]: ctx.sessionId,
    [ATTR_GEN_AI_OPERATION_NAME]: kind,
    [ATTR_GEN_AI_PROVIDER_NAME]: GEN_AI_PROVIDER_NAME_VALUE_ANTHROPIC,
    [ATTR_SERVER_ADDRESS]: isApi ? "api.anthropic.com" : undefined,
    [ATTR_GEN_AI_OUTPUT_TYPE]: hasOutputType
      ? GEN_AI_OUTPUT_TYPE_VALUE_TEXT
      : undefined,
    [ATTR_GEN_AI_REQUEST_MODEL]: model,
    [ATTR_GEN_AI_RESPONSE_MODEL]: model,
    [ATTR_GEN_AI_RESPONSE_ID]: responseId,
    [ATTR_GEN_AI_RESPONSE_FINISH_REASONS]: stopReasons?.length
      ? stopReasons.map(normalizeFinishReason)
      : undefined,
    [ATTR_GEN_AI_USAGE_INPUT_TOKENS]: usage?.input_tokens,
    [ATTR_GEN_AI_USAGE_OUTPUT_TOKENS]: usage?.output_tokens,
    [ATTR_GEN_AI_USAGE_CACHE_READ_INPUT_TOKENS]: usage?.cache_read_input_tokens,
    [ATTR_GEN_AI_USAGE_CACHE_CREATION_INPUT_TOKENS]:
      usage?.cache_creation_input_tokens,
  }
}

const metadata = (label: string) => `langfuse.observation.metadata.${label}`

const toolAttrs = ({
  block,
  error,
}: {
  block: ToolBlock
  error: string | undefined
}): Attributes => ({
  [ATTR_GEN_AI_TOOL_NAME]: block.toolName,
  [ATTR_GEN_AI_TOOL_TYPE]: block.toolType,
  [ATTR_GEN_AI_TOOL_CALL_ID]: block.correlationId,
  [ATTR_ERROR_TYPE]: error,
})

const otelKind = (kind: GroupedKind): SpanKind =>
  kind === GEN_AI_OPERATION_NAME_VALUE_CHAT ||
  kind === GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL
    ? SpanKind.CLIENT
    : SpanKind.INTERNAL

const chatLeaf = ({
  message,
  history,
  ctx,
}: {
  message: Extract<TranscriptMessage, { type: "assistant" }>
  history: readonly TranscriptMessage[]
  ctx: Ctx
}): Grouped => {
  const facts = factsFromAssistant(message)
  const time = message[META].timestamp.getTime()
  const inputMessages = history.map((msg) =>
    transcriptToMessage({ msg, asOutput: false }),
  )
  const outputMessages = [transcriptToMessage({ msg: message, asOutput: true })]

  return {
    spanName: facts.model ? `chat ${facts.model}` : "chat",
    spanKind: SpanKind.CLIENT,
    startTime: time,
    endTime: time,
    attributes: {
      ...commonAttrs({ kind: GEN_AI_OPERATION_NAME_VALUE_CHAT, ctx, facts }),
      [ATTR_GEN_AI_INPUT_MESSAGES]: JSON.stringify(inputMessages),
      [ATTR_GEN_AI_OUTPUT_MESSAGES]: JSON.stringify(outputMessages),
      [metadata("transcript_jq")]: message[META].debugExpr,
    },
  }
}

const toolLeaf = ({
  input,
  output,
  ctx,
}: {
  input?: SourcedToolBlock
  output?: SourcedToolBlock
  ctx: Ctx
}): Grouped => {
  const ref = input ?? output
  ok(ref, "toolLeaf needs at least one of input/output")

  const block = ref.block
  const error = input?.block.error ?? output?.block.error
  const orphaned = !input ? "tool_result" : !output ? "tool_use" : undefined
  const startTime = (input ?? output)!.msg[META].timestamp.getTime()
  const endTime = (output ?? input)!.msg[META].timestamp.getTime()
  const kind = block.kind

  return {
    spanName: block.toolName ? `${kind} ${block.toolName}` : kind,
    spanKind: otelKind(kind),
    startTime,
    endTime,
    attributes: {
      ...commonAttrs({ kind, ctx }),
      [ATTR_GEN_AI_TOOL_CALL_ARGUMENTS]: input
        ? JSON.stringify(input.block.value)
        : undefined,
      [ATTR_GEN_AI_TOOL_CALL_RESULT]: output
        ? JSON.stringify(output.block.value)
        : undefined,
      ...toolAttrs({ block, error }),
      [metadata("transcript_jq")]: ref.msg[META].debugExpr,
      [metadata("orphaned")]: orphaned,
    },
    status: error ? { code: SpanStatusCode.ERROR } : undefined,
  }
}

const buildLeaves = function* ({
  transcript,
  ctx,
}: {
  transcript: readonly TranscriptMessage[]
  ctx: Ctx
}): IteratorObject<Grouped> {
  const toolCalls = new Map<string, SourcedToolBlock>()
  let turnStart = false
  const tag = (g: Grouped): Grouped => {
    if (!turnStart) return g
    turnStart = false
    return { ...g, turnStart: true }
  }

  for (const [idx, msg] of transcript.entries()) {
    if (msg.type === "user") {
      turnStart = true
    }

    for (const raw of contents(msg)) {
      const extracted = extractBlock(msg.type, raw)
      if (
        extracted?.category !== "tool" ||
        extracted.correlationId === undefined
      ) {
        continue
      }
      const id = extracted.correlationId
      const sourced: SourcedToolBlock = { msg, block: extracted }

      if (extracted.type === GEN_AI_TOKEN_TYPE_VALUE_INPUT) {
        toolCalls.set(id, sourced)
        continue
      }

      const mate = toolCalls.get(id)
      toolCalls.delete(id)
      yield tag(toolLeaf({ input: mate, output: sourced, ctx }))
    }

    if (msg.type === "assistant") {
      yield tag(
        chatLeaf({ message: msg, history: transcript.slice(0, idx), ctx }),
      )
    }
  }

  for (const orphan of toolCalls.values()) {
    yield toolLeaf({ input: orphan, ctx })
  }
  return
}

const branch = ({
  kind,
  attributes,
  children,
  ctx,
}: {
  kind: GroupedKind
  attributes: Attributes
  children: NonEmpty<Grouped>
  ctx: Ctx
}): Grouped => {
  const agentName = attributes[ATTR_GEN_AI_AGENT_NAME]
  const target = typeof agentName === "string" ? agentName : undefined

  return {
    spanName: [kind, target].filter((n) => n).join(" "),
    spanKind: otelKind(kind),
    startTime: Math.min(...children.map((c) => c.startTime)),
    endTime: Math.max(...children.map((c) => c.endTime)),
    attributes: {
      ...commonAttrs({ kind, ctx }),
      ...attributes,
    },
    children,
  }
}

const groupAgents = function* ({
  hook,
  entries,
  ctx,
}: {
  hook: HookInput
  entries: IteratorObject<Grouped>
  ctx: Ctx
}): IteratorObject<Grouped> {
  if (hook.hook_event_name === "SubagentStop") {
    const children = entries.toArray()
    if (isNonEmpty(children)) {
      yield branch({
        kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
        attributes: {
          [ATTR_GEN_AI_AGENT_NAME]: hook.agent_type,
          [ATTR_GEN_AI_AGENT_ID]: hook.agent_id,
        },
        children,
        ctx,
      })
    }
    return
  }

  for (const chunk of chunkBy({
    source: entries,
    isBoundary: (e) => e.turnStart === true,
  })) {
    if (chunk.length === 1) {
      yield* chunk
      continue
    }

    yield branch({
      kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
      attributes: {
        [ATTR_GEN_AI_AGENT_NAME]: "claude-code",
        [ATTR_GEN_AI_AGENT_ID]: hook.session_id,
      },
      children: chunk,
      ctx,
    })
  }
  return
}

const emit = ({
  tracer,
  parentCtx,
  grouped,
}: {
  tracer: Tracer
  parentCtx: Context
  grouped: Grouped
}): void => {
  const span = tracer.startSpan(
    grouped.spanName,
    {
      startTime: grouped.startTime,
      kind: grouped.spanKind,
      attributes: grouped.attributes,
    },
    parentCtx,
  )
  if (grouped.status) {
    span.setStatus(grouped.status)
  }
  if (grouped.children) {
    const childCtx = trace.setSpan(parentCtx, span)
    for (const child of grouped.children) {
      emit({ tracer, parentCtx: childCtx, grouped: child })
    }
  }
  span.end(grouped.endTime)
}

const main = async (): Promise<void> => {
  const [hook, userId] = await Promise.all([hookInput(), gitUserName()])
  using _ = measure(`${hook.hook_event_name} (session=${hook.session_id})`)

  await using state = await openState(hook)
  await using otel = provider(hook)
  if (!otel) {
    return
  }

  const ctx = { userId, sessionId: hook.session_id } satisfies Ctx
  const transcript = await Array.fromAsync(parseMessages(hook, state.uuid))
  const leaves = buildLeaves({ transcript, ctx })
  const grouped = groupAgents({ hook, entries: leaves, ctx })

  const tracer = otel.provider.getTracer("claude-code")
  for (const group of grouped) {
    emit({ tracer, parentCtx: ROOT_CONTEXT, grouped: group })
  }

  await otel.provider.forceFlush()
  if (hook.hook_event_name !== "SubagentStop") {
    const tailUuid = transcript.at(-1)?.uuid
    if (tailUuid !== undefined) {
      state.uuid = tailUuid
    }
  }
}

await main()
