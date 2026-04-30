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

type BaseExtractedBlock = Readonly<{
  type: "input" | "output"
  kind: BlockKind
  value: unknown
}>

type ExtractedBlock =
  | (BaseExtractedBlock & { category: "user-text" })
  | (BaseExtractedBlock & { category: "agent-text" })
  | (BaseExtractedBlock & { category: "agent-thinking" })
  | (BaseExtractedBlock & {
      category: "tool"
      correlationId: string | undefined
      toolName?: string
      toolType?: "function" | "extension"
      error?: string
    })

type SourcedBlock = readonly [
  TranscriptMessage,
  ExtractedBlock & { [META]: { block: BlockType } },
]

type BaseGrouped = Readonly<{
  kind: GroupedKind
  spanName: string
  spanKind: SpanKind
  startTime: number
  endTime: number
  attributes: Attributes
  status?: { code: SpanStatusCode }
  inputAttr?: readonly [string, string]
  outputAttr?: readonly [string, string]
  blocks: readonly SourcedBlock[]
}>

type LeafGrouped = BaseGrouped &
  Readonly<{
    depthFromLeaf: 0
  }>

type BranchGrouped = BaseGrouped &
  Readonly<{
    depthFromLeaf: number
    children: readonly Grouped[]
  }>

type Grouped = LeafGrouped | BranchGrouped

type Ctx = { userId: string; sessionId: string }

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..")
const SESSIONS_DIR = resolve(ROOT, "var", "sessions")

const hookInput = async (): Promise<HookInput> => JSON.parse(await text(stdin))

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
  category,
  value,
}: {
  side: BaseExtractedBlock["type"]
  category: Exclude<ExtractedBlock["category"], "tool">
  value: unknown
}): ExtractedBlock => ({
  category,
  type: side,
  kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
  value,
})

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
}): ExtractedBlock => ({
  category: "tool",
  type: "input",
  kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
  correlationId,
  toolName,
  toolType,
  value,
})

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
}): ExtractedBlock => ({
  category: "tool",
  type: "output",
  kind,
  correlationId,
  value,
  ...(error !== undefined ? { error } : {}),
})

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
  const textCategory = role === "assistant" ? "agent-text" : "user-text"

  if (typeof block === "string") {
    return extractChat({ side, category: textCategory, value: block })
  }

  switch (block.type) {
    case "text":
      return extractChat({
        side,
        category: textCategory,
        value: block.citations?.length
          ? { text: block.text, citations: block.citations }
          : block.text,
      })
    case "thinking":
      return block.thinking
        ? extractChat({
            side,
            category: "agent-thinking",
            value: block.thinking,
          })
        : undefined
    case "redacted_thinking":
      return block.data
        ? extractChat({ side, category: "agent-thinking", value: block.data })
        : undefined
    case "compaction":
      return block.content
        ? extractChat({ side, category: textCategory, value: block.content })
        : undefined
    case "image":
      return extractChat({
        side,
        category: textCategory,
        value: imageValue(block),
      })

    case "mcp_tool_use":
      return extractToolUse({
        toolName: `mcp__${block.server_name}__${block.name}`,
        toolType: "extension",
        correlationId: block.id,
        value: {
          name: block.name,
          input: block.input,
          server_name: block.server_name,
        },
      })
    case "server_tool_use":
      return extractToolUse({
        toolName: block.name,
        toolType: "extension",
        correlationId: block.id,
        value: { name: block.name, input: block.input },
      })
    case "tool_use":
      return extractToolUse({
        toolName: block.name,
        toolType: "function",
        correlationId: block.id,
        value: { name: block.name, input: block.input },
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
      return {
        category: textCategory,
        type: side,
        kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
        value: documentValue(block),
      }
    case "search_result":
      return {
        category: textCategory,
        type: side,
        kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
        value: {
          content: block.content.map((item) => item.text),
          source: block.source,
          title: block.title,
        },
      }
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

const messagePart = (block: ExtractedBlock) => ({
  type: block.category === "agent-thinking" ? "reasoning" : "text",
  content:
    typeof block.value === "string" ? block.value : JSON.stringify(block.value),
})

const wrapMessage = (msg: TranscriptMessage, block: ExtractedBlock) => [
  {
    role: msg.type,
    parts: [messagePart(block)],
    ...(block.type === "output"
      ? {
          finish_reason:
            msg.type === "assistant"
              ? (msg.message.stop_reason ?? "stop")
              : "stop",
        }
      : {}),
  },
]

const otelKind = (kind: GroupedKind): SpanKind =>
  kind === GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL
    ? SpanKind.INTERNAL
    : SpanKind.CLIENT

type AssistantMessage = Extract<TranscriptMessage, { type: "assistant" }>

const uniqueAssistants = (
  blocks: readonly SourcedBlock[],
): readonly AssistantMessage[] => {
  const seen = new Set<string>()
  return blocks
    .map(([m]) => m)
    .filter(
      (m): m is AssistantMessage =>
        m.type === "assistant" && !seen.has(m.uuid) && !!seen.add(m.uuid),
    )
}

const ioAttr = (
  msg: TranscriptMessage,
  block: ExtractedBlock,
): readonly [string, string] => {
  const isOutput = block.type === "output"
  const isTool = block.category === "tool"
  const key = isTool
    ? isOutput
      ? ATTR_GEN_AI_TOOL_CALL_RESULT
      : ATTR_GEN_AI_TOOL_CALL_ARGUMENTS
    : isOutput
      ? ATTR_GEN_AI_OUTPUT_MESSAGES
      : ATTR_GEN_AI_INPUT_MESSAGES
  const value = isTool ? block.value : wrapMessage(msg, block)
  return [key, JSON.stringify(value)]
}

const computeIoAttrs = (
  blocks: readonly SourcedBlock[],
  flags: { isOrphanedLeaf: boolean; excludeTool: boolean },
): {
  inputAttr?: readonly [string, string]
  outputAttr?: readonly [string, string]
} => {
  const { isOrphanedLeaf, excludeTool } = flags

  const output = blocks.findLast(
    ([, b]) => b.type === "output" && (!excludeTool || b.category !== "tool"),
  )
  const [outputMsg, lastOutputBlock] = output ?? []
  const outputAttr =
    outputMsg && lastOutputBlock
      ? ioAttr(outputMsg, lastOutputBlock)
      : undefined

  const lastCorrelationId =
    lastOutputBlock?.category === "tool"
      ? lastOutputBlock.correlationId
      : undefined

  const inputEntry = blocks.find(([, block]) => {
    if (block.type !== "input") {
      return false
    }
    if (block.category === "tool") {
      if (excludeTool) return false
      return block.correlationId === lastCorrelationId || isOrphanedLeaf
    }
    return true
  })
  const [inputMsg, firstInputBlock] = inputEntry ?? []
  const inputAttr =
    inputMsg && firstInputBlock ? ioAttr(inputMsg, firstInputBlock) : undefined

  return { inputAttr, outputAttr }
}

const isLeaf = (g: Grouped): g is LeafGrouped => g.depthFromLeaf === 0

type AggregateFacts = {
  model: string | undefined
  responseId: string | undefined
  stopReasons: string[]
  inputTokens: number
  outputTokens: number
  cacheReadInputTokens: number
  cacheCreationInputTokens: number
}

const aggregateFacts = (blocks: readonly SourcedBlock[]): AggregateFacts => {
  const assistants = uniqueAssistants(blocks)
  const usage = assistants.reduce(
    (acc, m) => ({
      inputTokens: acc.inputTokens + m.message.usage.input_tokens,
      outputTokens: acc.outputTokens + m.message.usage.output_tokens,
      cacheReadInputTokens:
        acc.cacheReadInputTokens +
        (m.message.usage.cache_read_input_tokens ?? 0),
      cacheCreationInputTokens:
        acc.cacheCreationInputTokens +
        (m.message.usage.cache_creation_input_tokens ?? 0),
    }),
    {
      inputTokens: 0,
      outputTokens: 0,
      cacheReadInputTokens: 0,
      cacheCreationInputTokens: 0,
    },
  )
  return {
    model: assistants.findLast((a) => a.message.model !== "<synthetic>")
      ?.message.model,
    responseId: assistants.at(-1)?.message.id,
    stopReasons: assistants
      .map((m) => m.message.stop_reason)
      .filter((r) => r != null),
    ...usage,
  }
}

const aggregateAttrs = (
  kind: GroupedKind,
  facts: AggregateFacts,
): Attributes => ({
  ...(facts.model
    ? {
        [ATTR_GEN_AI_REQUEST_MODEL]: facts.model,
        [ATTR_GEN_AI_RESPONSE_MODEL]: facts.model,
      }
    : {}),
  ...(facts.responseId ? { [ATTR_GEN_AI_RESPONSE_ID]: facts.responseId } : {}),
  ...(kind === GEN_AI_OPERATION_NAME_VALUE_CHAT && facts.stopReasons.length
    ? { [ATTR_GEN_AI_RESPONSE_FINISH_REASONS]: facts.stopReasons }
    : {}),
  ...(facts.inputTokens
    ? { [ATTR_GEN_AI_USAGE_INPUT_TOKENS]: facts.inputTokens }
    : {}),
  ...(facts.outputTokens
    ? { [ATTR_GEN_AI_USAGE_OUTPUT_TOKENS]: facts.outputTokens }
    : {}),
  ...(facts.cacheReadInputTokens
    ? {
        [ATTR_GEN_AI_USAGE_CACHE_READ_INPUT_TOKENS]: facts.cacheReadInputTokens,
      }
    : {}),
  ...(facts.cacheCreationInputTokens
    ? {
        [ATTR_GEN_AI_USAGE_CACHE_CREATION_INPUT_TOKENS]:
          facts.cacheCreationInputTokens,
      }
    : {}),
})

const commonAttrs = ({
  kind,
  ctx,
  isOperation,
  facts,
}: {
  kind: GroupedKind
  ctx: Ctx
  isOperation: boolean
  facts: AggregateFacts
}): Attributes => ({
  [ATTR_USER_ID]: ctx.userId,
  [ATTR_GEN_AI_CONVERSATION_ID]: ctx.sessionId,
  ...(isOperation
    ? {
        [ATTR_GEN_AI_OPERATION_NAME]: kind,
        [ATTR_GEN_AI_PROVIDER_NAME]: GEN_AI_PROVIDER_NAME_VALUE_ANTHROPIC,
      }
    : {}),
  ...aggregateAttrs(kind, facts),
})

const metadata = (label: string) => `langfuse.observation.metadata.${label}`

const leaf = ({
  blocks,
  ctx,
  orphaned,
}: {
  blocks: readonly [SourcedBlock, ...SourcedBlock[]]
  ctx: Ctx
  orphaned?: "tool_use" | "tool_result"
}): LeafGrouped => {
  const [[startMsg, firstBlock]] = blocks
  const kind = firstBlock.kind
  const isOperation = firstBlock.category === "tool"

  type ToolBlock = Extract<SourcedBlock[1], { category: "tool" }>
  const toolBlock = blocks
    .map(([, b]) => b)
    .find((b): b is ToolBlock => b.category === "tool")
  const toolError = blocks
    .map(([, b]) => (b.category === "tool" && b.error ? b.error : undefined))
    .find((e) => e)

  const times = blocks.map(([m]) => m[META].timestamp.getTime())
  const facts = aggregateFacts(blocks)
  const { inputAttr, outputAttr } = computeIoAttrs(blocks, {
    isOrphanedLeaf: !!orphaned,
    excludeTool: false,
  })

  return {
    kind,
    spanName: toolBlock?.toolName
      ? `execute_tool ${toolBlock.toolName}`
      : startMsg.type,
    spanKind: isOperation ? otelKind(kind) : SpanKind.INTERNAL,
    startTime: Math.min(...times),
    endTime: Math.max(...times),
    attributes: {
      ...commonAttrs({ kind, ctx, isOperation, facts }),
      [metadata("transcript_jq")]: startMsg[META].debugExpr,
      [metadata("block_types")]: blocks.map(([, b]) => b[META].block),
      ...(orphaned ? { [metadata("orphaned")]: orphaned } : {}),
      ...(toolBlock?.toolName
        ? { [ATTR_GEN_AI_TOOL_NAME]: toolBlock.toolName }
        : {}),
      ...(toolBlock?.toolType
        ? { [ATTR_GEN_AI_TOOL_TYPE]: toolBlock.toolType }
        : {}),
      ...(toolBlock?.correlationId
        ? { [ATTR_GEN_AI_TOOL_CALL_ID]: toolBlock.correlationId }
        : {}),
      ...(toolError ? { [ATTR_ERROR_TYPE]: toolError } : {}),
    },
    ...(toolError ? { status: { code: SpanStatusCode.ERROR } } : {}),
    ...(inputAttr ? { inputAttr } : {}),
    ...(outputAttr ? { outputAttr } : {}),
    blocks,
    depthFromLeaf: 0,
  }
}

const branch = ({
  kind,
  partialAttrs,
  children,
  ctx,
}: {
  kind: GroupedKind
  partialAttrs: Attributes
  children: readonly Grouped[]
  ctx: Ctx
}): BranchGrouped | undefined => {
  if (!children.length) {
    return undefined
  }
  const blocks = children.flatMap((c) => c.blocks)
  if (!blocks.length) {
    return undefined
  }

  const facts = aggregateFacts(blocks)
  const agentName = partialAttrs[ATTR_GEN_AI_AGENT_NAME]
  const target = (() => {
    switch (kind) {
      case GEN_AI_OPERATION_NAME_VALUE_CHAT:
        return facts.model
      case GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT:
        return typeof agentName === "string" ? agentName : undefined
      default:
        return undefined
    }
  })()

  const { inputAttr, outputAttr } = computeIoAttrs(blocks, {
    isOrphanedLeaf: false,
    excludeTool: true,
  })

  return {
    kind,
    spanName: [kind, target].filter((n) => n).join(" "),
    spanKind: otelKind(kind),
    startTime: Math.min(...children.map((c) => c.startTime)),
    endTime: Math.max(...children.map((c) => c.endTime)),
    attributes: {
      ...commonAttrs({ kind, ctx, isOperation: true, facts }),
      ...partialAttrs,
    },
    ...(inputAttr ? { inputAttr } : {}),
    ...(outputAttr ? { outputAttr } : {}),
    blocks,
    depthFromLeaf: 1 + Math.max(...children.map((c) => c.depthFromLeaf)),
    children,
  }
}

const correlateToolCalls = function* (
  extracted: IteratorObject<SourcedBlock>,
  ctx: Ctx,
): IteratorObject<Grouped> {
  const acc = new Map<string, SourcedBlock>()

  for (const entry of extracted) {
    const [, block] = entry

    if (block.category !== "tool" || block.correlationId === undefined) {
      yield leaf({ blocks: [entry], ctx })
      continue
    }

    const id = block.correlationId
    if (block.type === "input") {
      acc.set(id, entry)
      continue
    }

    const mate = acc.get(id)
    if (mate === undefined) {
      yield leaf({ blocks: [entry], ctx, orphaned: "tool_result" })
      continue
    }
    acc.delete(id)
    yield leaf({ blocks: [mate, entry], ctx })
  }

  for (const entry of acc.values()) {
    yield leaf({ blocks: [entry], ctx, orphaned: "tool_use" })
  }

  return
}

const wrapOrPass = function* ({
  kind,
  attrs,
  items,
  ctx,
}: {
  kind: GroupedKind
  attrs: Attributes
  items: readonly Grouped[]
  ctx: Ctx
}): IteratorObject<Grouped> {
  const [first, ...rest] = items
  if (!first) {
    return
  }
  if (!rest.length) {
    yield first
    return
  }
  const wrapped = branch({ kind, partialAttrs: attrs, children: items, ctx })
  if (wrapped) yield wrapped
  return
}

const generationId = (grouped: Grouped): string | undefined => {
  for (const [msg] of grouped.blocks) {
    if (msg.type === "assistant") return msg.message.id
  }
  return undefined
}

const isOperationLeaf = (g: Grouped): boolean =>
  isLeaf(g) && ATTR_GEN_AI_OPERATION_NAME in g.attributes

const groupByGeneration = function* (
  entries: IteratorObject<Grouped>,
  ctx: Ctx,
): IteratorObject<Grouped> {
  type Tagged = { genId: string | undefined; entry: Grouped }
  const tagged = entries
    .map((entry) => ({ genId: generationId(entry), entry }) satisfies Tagged)
    .toArray()

  const chatBuckets = Map.groupBy(
    tagged.filter((t) => t.genId !== undefined && !isOperationLeaf(t.entry)),
    ({ genId }) => genId,
  )

  const emitted = new Set<string>()
  for (const { genId, entry } of tagged) {
    if (genId === undefined || isOperationLeaf(entry)) {
      yield entry
      continue
    }
    if (emitted.has(genId)) {
      continue
    }
    emitted.add(genId)

    const children = chatBuckets.get(genId)?.map((c) => c.entry) ?? []
    yield* wrapOrPass({
      kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
      attrs: {},
      items: children,
      ctx,
    })
  }

  return
}

const isTurnStart = (entry: Grouped): boolean => {
  if (!isLeaf(entry)) {
    return false
  }
  const [first] = entry.blocks
  if (!first) {
    return false
  }
  const [msg, block] = first
  return msg.type === "user" && block.category !== "tool"
}

const groupTurns = function* (
  entries: IteratorObject<Grouped>,
  ctx: Ctx,
): IteratorObject<Grouped> {
  const turnAttrs = { [ATTR_GEN_AI_AGENT_NAME]: "claude-code" }
  let buffer: Grouped[] = []
  for (const entry of entries) {
    if (isTurnStart(entry)) {
      yield* wrapOrPass({
        kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
        attrs: turnAttrs,
        items: buffer,
        ctx,
      })
      buffer = []
    }
    buffer.push(entry)
  }
  yield* wrapOrPass({
    kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
    attrs: turnAttrs,
    items: buffer,
    ctx,
  })
  return
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
    const wrapped = branch({
      kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
      partialAttrs: {
        [ATTR_GEN_AI_AGENT_NAME]: hook.agent_type,
        [ATTR_GEN_AI_AGENT_ID]: hook.agent_id,
      },
      children: entries.toArray(),
      ctx,
    })
    if (wrapped) {
      yield wrapped
    }
    return
  }

  yield* groupTurns(entries, ctx)
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
  if (grouped.outputAttr) {
    span.setAttribute(...grouped.outputAttr)
  }
  if (grouped.inputAttr) {
    span.setAttribute(...grouped.inputAttr)
  }
  if (!isLeaf(grouped)) {
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
  const generations = groupByGeneration(correlated, ctx)
  const grouped = groupAgents({ hook, entries: generations, ctx })

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
