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
} from "@opentelemetry/semantic-conventions/incubating"
import { fail } from "node:assert/strict"
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
const isNonNull = <T>(v: T): v is NonNullable<T> => v != null

type TranscriptMeta = Readonly<{
  timestamp: Date
  debugExpr: string
}>

type MessageBlock = string | BetaContentBlock | BetaContentBlockParam
type BlockType = "string" | (BetaContentBlock | BetaContentBlockParam)["type"]

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

type ExtractedBlock =
  | Readonly<{
      category: "chat"
      type: "input" | "output"
      value: unknown
      thinking?: boolean
    }>
  | Readonly<{
      category: "tool"
      type: "input" | "output"
      kind: BlockKind
      value: unknown
      correlationId: string | undefined
      toolName?: string
      toolType?: "function" | "extension"
      error?: string
    }>

type SourcedBlock = Readonly<{
  msg: TranscriptMessage
  block: ExtractedBlock & { [META]: { block: BlockType } }
}>

type Bundle = NonEmpty<SourcedBlock>

type Grouped = Readonly<{
  blocks: readonly SourcedBlock[]
  kind: GroupedKind
  spanName: string
  spanKind: SpanKind
  startTime: number
  endTime: number
  attributes: Attributes
  status?: { code: SpanStatusCode }
  children?: readonly Grouped[]
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
  thinking,
  value,
}: {
  side: ExtractedBlock["type"]
  thinking?: boolean
  value: unknown
}) =>
  ({
    category: "chat",
    type: side,
    value,
    ...(thinking ? { thinking: true } : {}),
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
    type: "input",
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
    type: "output",
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

const extractBlock = (
  role: TranscriptMessage["type"],
  block: MessageBlock,
): ExtractedBlock | undefined => {
  const side = role === "assistant" ? "output" : "input"

  if (typeof block === "string") {
    return extractChat({ side, value: block })
  }

  switch (block.type) {
    case "text":
      return extractChat({
        side,
        value: block.citations?.length
          ? { text: block.text, citations: block.citations }
          : block.text,
      })
    case "thinking":
      return block.thinking
        ? extractChat({ side, thinking: true, value: block.thinking })
        : undefined
    case "redacted_thinking":
      return block.data
        ? extractChat({ side, thinking: true, value: block.data })
        : undefined
    case "compaction":
      return block.content
        ? extractChat({ side, value: block.content })
        : undefined
    case "image":
      return extractChat({ side, value: imageValue(block) })

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
      return extractChat({ side, value: documentValue(block) })
    case "search_result":
      return extractChat({
        side,
        value: {
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
        value: { file_id: block.file_id },
      } satisfies ExtractedBlock

    default:
      fail(block satisfies never)
  }
}

const extractContent = function* (
  messages: IteratorObject<TranscriptMessage>,
): IteratorObject<SourcedBlock> {
  for (const msg of messages) {
    for (const raw of contents(msg)) {
      const extracted = extractBlock(msg.type, raw)
      if (!extracted) {
        continue
      }

      const blockType = typeof raw === "string" ? "string" : raw.type
      yield {
        msg,
        block: { ...extracted, [META]: { block: blockType } },
      } satisfies SourcedBlock
    }
  }

  return
}

const messagePart = (block: ExtractedBlock) => {
  if (block.category === "tool") {
    const id = block.correlationId
    if (block.type === "input") {
      return {
        type: "tool_call",
        ...(id !== undefined ? { id } : {}),
        ...(block.toolName ? { name: block.toolName } : {}),
        arguments: block.value,
      }
    }
    return {
      type: "tool_call_response",
      ...(id !== undefined ? { id } : {}),
      result: block.value,
    }
  }
  return {
    type: block.thinking ? "reasoning" : "text",
    content:
      typeof block.value === "string"
        ? block.value
        : JSON.stringify(block.value),
  }
}

const normalizeFinishReason = (() => {
  const map = new Map<string, string>([
    ["end_turn", "stop"],
    ["stop_sequence", "stop"],
    ["pause_turn", "stop"],
    ["max_tokens", "length"],
    ["tool_use", "tool_calls"],
    ["refusal", "content_filter"],
  ])

  return (raw: string | null | undefined) => map.get(raw ?? "") ?? raw ?? "stop"
})()

const wrapMessage = (
  msg: TranscriptMessage,
  blocks: NonEmpty<ExtractedBlock>,
) => [
  {
    role: msg.type,
    parts: blocks.map(messagePart),
    ...(blocks[0].type === "output"
      ? {
          finish_reason:
            msg.type === "assistant"
              ? normalizeFinishReason(msg.message.stop_reason)
              : "stop",
        }
      : {}),
  },
]

const ioAttr = (
  msg: TranscriptMessage,
  blocks: NonEmpty<ExtractedBlock>,
): Attributes => {
  const [first] = blocks
  const isOutput = first.type === "output"
  const isTool = first.category === "tool"
  const key = isTool
    ? isOutput
      ? ATTR_GEN_AI_TOOL_CALL_RESULT
      : ATTR_GEN_AI_TOOL_CALL_ARGUMENTS
    : isOutput
      ? ATTR_GEN_AI_OUTPUT_MESSAGES
      : ATTR_GEN_AI_INPUT_MESSAGES
  const value = isTool ? first.value : wrapMessage(msg, blocks)
  return { [key]: JSON.stringify(value) }
}

const leafIo = (blocks: Bundle): Attributes => {
  const [first, ...rest] = blocks
  if (first.block.category !== "tool") {
    const extracted = [first.block, ...rest.map((s) => s.block)] as const
    return ioAttr(first.msg, extracted)
  }

  const input = blocks.find((s) => s.block.type === "input")
  const output = blocks.findLast((s) => s.block.type === "output")
  return {
    ...(input ? ioAttr(input.msg, [input.block]) : {}),
    ...(output ? ioAttr(output.msg, [output.block]) : {}),
  }
}

const branchIo = (sourceBlocks: readonly SourcedBlock[]): Attributes => {
  const messageBlocks = (msg: TranscriptMessage | undefined) =>
    msg
      ? sourceBlocks
          .values()
          .filter((b) => b.msg === msg && b.block.category !== "tool")
          .map(({ block }) => block)
          .toArray()
      : []

  const output = sourceBlocks.findLast(
    ({ block }) => block.type === "output" && block.category !== "tool",
  )
  const outputBlocks = messageBlocks(output?.msg)

  const input = sourceBlocks.find(
    ({ block }) => block.type === "input" && block.category !== "tool",
  )
  const inputBlocks = messageBlocks(input?.msg)

  return {
    ...(input && isNonEmpty(inputBlocks) ? ioAttr(input.msg, inputBlocks) : {}),
    ...(output && isNonEmpty(outputBlocks)
      ? ioAttr(output.msg, outputBlocks)
      : {}),
  }
}

const commonAttrs = ({
  kind,
  ctx,
  isOperation,
  blocks,
}: {
  kind: GroupedKind
  ctx: Ctx
  isOperation: boolean
  blocks: readonly SourcedBlock[]
}): Attributes => {
  const seen = new Set<string>()
  const assistants = blocks
    .values()
    .map((b) => b.msg)
    .filter((msg) => msg.type === "assistant")
    .filter((msg) => !seen.has(msg.message.id) && !!seen.add(msg.message.id))
    .toArray()

  const model = assistants.findLast((a) => a.message.model !== "<synthetic>")
    ?.message.model
  const responseId = assistants.at(-1)?.message.id
  const stopReasons = assistants
    .values()
    .map((m) => m.message.stop_reason)
    .filter(isNonNull)
    .toArray()

  const usage =
    isOperation && kind === GEN_AI_OPERATION_NAME_VALUE_CHAT
      ? assistants.reduce(
          (acc, { message: { usage: u } }) => ({
            input_tokens:
              acc.input_tokens +
              u.input_tokens +
              (u.cache_read_input_tokens ?? 0) +
              (u.cache_creation_input_tokens ?? 0),
            output_tokens: acc.output_tokens + u.output_tokens,
            cache_read_input_tokens:
              acc.cache_read_input_tokens + (u.cache_read_input_tokens ?? 0),
            cache_creation_input_tokens:
              acc.cache_creation_input_tokens +
              (u.cache_creation_input_tokens ?? 0),
          }),
          {
            input_tokens: 0,
            output_tokens: 0,
            cache_read_input_tokens: 0,
            cache_creation_input_tokens: 0,
          },
        )
      : undefined

  return {
    [ATTR_USER_ID]: ctx.userId,
    [ATTR_GEN_AI_CONVERSATION_ID]: ctx.sessionId,
    ...(isOperation
      ? {
          [ATTR_GEN_AI_OPERATION_NAME]: kind,
          [ATTR_GEN_AI_PROVIDER_NAME]: GEN_AI_PROVIDER_NAME_VALUE_ANTHROPIC,
        }
      : {}),
    ...(isOperation &&
    (kind === GEN_AI_OPERATION_NAME_VALUE_CHAT ||
      kind === GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL)
      ? { [ATTR_SERVER_ADDRESS]: "api.anthropic.com" }
      : {}),
    ...(isOperation && kind !== GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL
      ? { [ATTR_GEN_AI_OUTPUT_TYPE]: GEN_AI_OUTPUT_TYPE_VALUE_TEXT }
      : {}),
    ...(model
      ? {
          [ATTR_GEN_AI_REQUEST_MODEL]: model,
          [ATTR_GEN_AI_RESPONSE_MODEL]: model,
        }
      : {}),
    ...(responseId ? { [ATTR_GEN_AI_RESPONSE_ID]: responseId } : {}),
    ...(kind === GEN_AI_OPERATION_NAME_VALUE_CHAT && stopReasons.length
      ? {
          [ATTR_GEN_AI_RESPONSE_FINISH_REASONS]: stopReasons.map(
            normalizeFinishReason,
          ),
        }
      : {}),
    ...(usage?.input_tokens
      ? { [ATTR_GEN_AI_USAGE_INPUT_TOKENS]: usage.input_tokens }
      : {}),
    ...(usage?.output_tokens
      ? { [ATTR_GEN_AI_USAGE_OUTPUT_TOKENS]: usage.output_tokens }
      : {}),
    ...(usage?.cache_read_input_tokens
      ? {
          [ATTR_GEN_AI_USAGE_CACHE_READ_INPUT_TOKENS]:
            usage.cache_read_input_tokens,
        }
      : {}),
    ...(usage?.cache_creation_input_tokens
      ? {
          [ATTR_GEN_AI_USAGE_CACHE_CREATION_INPUT_TOKENS]:
            usage.cache_creation_input_tokens,
        }
      : {}),
  }
}

const metadata = (label: string) => `langfuse.observation.metadata.${label}`

const toolAttrs = ({
  block,
  error,
}: {
  block: Extract<ExtractedBlock, { category: "tool" }>
  error: string | undefined
}): Attributes => ({
  ...(block.toolName ? { [ATTR_GEN_AI_TOOL_NAME]: block.toolName } : {}),
  ...(block.toolType ? { [ATTR_GEN_AI_TOOL_TYPE]: block.toolType } : {}),
  ...(block.correlationId
    ? { [ATTR_GEN_AI_TOOL_CALL_ID]: block.correlationId }
    : {}),
  ...(error ? { [ATTR_ERROR_TYPE]: error } : {}),
})

const otelKind = (kind: GroupedKind): SpanKind =>
  kind === GEN_AI_OPERATION_NAME_VALUE_CHAT ||
  kind === GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL
    ? SpanKind.CLIENT
    : SpanKind.INTERNAL

const leaf = ({
  bundle,
  ctx,
  orphaned,
}: {
  bundle: Bundle
  ctx: Ctx
  orphaned?: "tool_use" | "tool_result"
}): Grouped => {
  const [{ msg: startMsg, block: firstBlock }] = bundle
  const tool =
    firstBlock.category === "tool"
      ? {
          kind: firstBlock.kind,
          block: firstBlock,
          error: bundle
            .values()
            .map((s) => s.block)
            .filter((b) => b.category === "tool")
            .map((b) => b.error)
            .find((e) => e),
        }
      : undefined

  const isOperation = tool !== undefined || startMsg.type === "assistant"
  const kind = tool?.kind ?? GEN_AI_OPERATION_NAME_VALUE_CHAT
  const model = bundle
    .values()
    .map((s) => s.msg)
    .filter((msg) => msg.type === "assistant")
    .map((msg) => msg.message.model)
    .filter((m) => m !== "<synthetic>")
    .toArray()
    .at(-1)
  const times = bundle.map(({ msg }) => msg[META].timestamp.getTime())

  const spanName = tool?.block.toolName
    ? `execute_tool ${tool.block.toolName}`
    : model
      ? `chat ${model}`
      : startMsg.type

  return {
    kind,
    spanName,
    spanKind: isOperation ? otelKind(kind) : SpanKind.INTERNAL,
    startTime: Math.min(...times),
    endTime: Math.max(...times),
    attributes: {
      ...commonAttrs({ kind, ctx, isOperation, blocks: bundle }),
      ...leafIo(bundle),
      [metadata("transcript_jq")]: startMsg[META].debugExpr,
      [metadata("block_types")]: bundle.map(({ block }) => block[META].block),
      ...(orphaned ? { [metadata("orphaned")]: orphaned } : {}),
      ...(tool ? toolAttrs(tool) : {}),
    },
    ...(tool?.error ? { status: { code: SpanStatusCode.ERROR } } : {}),
    blocks: bundle,
  }
}

const correlateToolCalls = function* (
  sourcedBlocks: IteratorObject<SourcedBlock>,
  ctx: Ctx,
): IteratorObject<Grouped> {
  const acc = new Map<string, SourcedBlock>()

  for (const sourced of sourcedBlocks) {
    if (
      sourced.block.category !== "tool" ||
      sourced.block.correlationId === undefined
    ) {
      yield leaf({ bundle: [sourced], ctx })
      continue
    }

    const id = sourced.block.correlationId
    if (sourced.block.type === "input") {
      acc.set(id, sourced)
      continue
    }

    const mate = acc.get(id)
    if (mate === undefined) {
      yield leaf({ bundle: [sourced], ctx, orphaned: "tool_result" })
      continue
    }
    acc.delete(id)
    yield leaf({ bundle: [mate, sourced], ctx })
  }

  for (const entry of acc.values()) {
    yield leaf({ bundle: [entry], ctx, orphaned: "tool_use" })
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
  children: readonly Grouped[]
  ctx: Ctx
}): Grouped => {
  const blocks = children.flatMap((c) => c.blocks)
  const agentName = attributes[ATTR_GEN_AI_AGENT_NAME]
  const target = typeof agentName === "string" ? agentName : undefined

  return {
    kind,
    spanName: [kind, target].filter((n) => n).join(" "),
    spanKind: otelKind(kind),
    startTime: Math.min(...children.map((c) => c.startTime)),
    endTime: Math.max(...children.map((c) => c.endTime)),
    attributes: {
      ...commonAttrs({ kind, ctx, isOperation: true, blocks }),
      ...branchIo(blocks),
      ...attributes,
    },
    blocks,
    children,
  }
}

const isTurnStart = (entry: Grouped): boolean => {
  const [first] = entry.blocks
  return (
    entry.children === undefined &&
    first?.msg.type === "user" &&
    first?.block.category !== "tool"
  )
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
    yield branch({
      kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
      attributes: {
        [ATTR_GEN_AI_AGENT_NAME]: hook.agent_type,
        [ATTR_GEN_AI_AGENT_ID]: hook.agent_id,
      },
      children: entries.toArray(),
      ctx,
    })
    return
  }

  for (const chunk of chunkBy({ source: entries, isBoundary: isTurnStart })) {
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
  const transcriptRows = await Array.fromAsync(parseMessages(hook, state.uuid))
  const extracted = extractContent(transcriptRows.values())
  const correlated = correlateToolCalls(extracted, ctx)
  const grouped = groupAgents({ hook, entries: correlated, ctx })

  const tracer = otel.provider.getTracer("claude-code")
  for (const group of grouped) {
    emit({ tracer, parentCtx: ROOT_CONTEXT, grouped: group })
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
