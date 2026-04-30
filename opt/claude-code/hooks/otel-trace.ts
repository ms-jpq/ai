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
  ATTR_GEN_AI_REQUEST_MODEL,
  ATTR_GEN_AI_RESPONSE_FINISH_REASONS,
  ATTR_GEN_AI_RESPONSE_ID,
  ATTR_GEN_AI_RESPONSE_MODEL,
  ATTR_GEN_AI_TOOL_CALL_ARGUMENTS,
  ATTR_GEN_AI_TOOL_CALL_ID,
  ATTR_GEN_AI_TOOL_CALL_RESULT,
  ATTR_GEN_AI_TOOL_NAME,
  ATTR_USER_ID,
  GEN_AI_OPERATION_NAME_VALUE_CHAT,
  GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
  GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
  GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
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

const extractChat = (
  side: BaseExtractedBlock["type"],
  category: Exclude<ExtractedBlock["category"], "tool">,
  value: unknown,
): ExtractedBlock => ({
  category,
  type: side,
  kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
  value,
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
    return extractChat(side, textCategory, block)
  }

  switch (block.type) {
    case "text":
      return extractChat(
        side,
        textCategory,
        block.citations?.length
          ? { text: block.text, citations: block.citations }
          : block.text,
      )
    case "thinking":
      return block.thinking
        ? extractChat(side, "agent-thinking", block.thinking)
        : undefined
    case "redacted_thinking":
      return block.data
        ? extractChat(side, "agent-thinking", block.data)
        : undefined
    case "compaction":
      return block.content
        ? extractChat(side, textCategory, block.content)
        : undefined
    case "image":
      return extractChat(side, textCategory, imageValue(block))

    case "mcp_tool_use":
      return {
        category: "tool",
        type: "input",
        kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
        correlationId: block.id,
        toolName: `mcp__${block.server_name}__${block.name}`,
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
        type: "input",
        kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
        correlationId: block.id,
        toolName: block.name,
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
      return {
        category: "tool",
        type: "output",
        error: block.is_error ? "_OTHER" : undefined,
        kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
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
            type: "output",
            error: block.content.error_code,
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
            correlationId: block.tool_use_id,
            value: block.content.error_code,
          }
        case "encrypted_code_execution_result":
          return {
            category: "tool",
            type: "output",
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
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
            type: "output",
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
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
            type: "output",
            error: block.content.error_code,
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
            correlationId: block.tool_use_id,
            value: {
              error_code: block.content.error_code,
              error_message: block.content.error_message,
            },
          }
        case "text_editor_code_execution_view_result":
          return {
            category: "tool",
            type: "output",
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
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
            type: "output",
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
            correlationId: block.tool_use_id,
            value: { is_file_update: block.content.is_file_update },
          }
        case "text_editor_code_execution_str_replace_result":
          return {
            category: "tool",
            type: "output",
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
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
            type: "output",
            error: block.content.error_code,
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
            correlationId: block.tool_use_id,
            value: rest,
          }
        }
        case "tool_search_tool_search_result":
          return {
            category: "tool",
            type: "output",
            kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
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
        return {
          category: "tool",
          type: "output",
          kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
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
        type: "output",
        error: block.content.error_code,
        kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
        correlationId: block.tool_use_id,
        value: block.content.error_code,
      }
    case "web_fetch_tool_result":
      switch (block.content.type) {
        case "web_fetch_tool_result_error":
          return {
            category: "tool",
            type: "output",
            error: block.content.error_code,
            kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
            correlationId: block.tool_use_id,
            value: block.content.error_code,
          }
        case "web_fetch_result":
          return {
            category: "tool",
            type: "output",
            kind: GEN_AI_OPERATION_NAME_VALUE_RETRIEVAL,
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

const metadata = (label: string) => `langfuse.observation.metadata.${label}`

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

const computeIoAttrs = (
  blocks: readonly SourcedBlock[],
  isOrphanedLeaf: boolean,
): {
  inputAttr?: readonly [string, string]
  outputAttr?: readonly [string, string]
} => {
  const output = blocks.findLast(([, b]) => b.type === "output")
  const [outputMsg, lastOutputBlock] = output ?? []

  const outputAttr =
    lastOutputBlock && outputMsg
      ? lastOutputBlock.category === "tool"
        ? ([
            ATTR_GEN_AI_TOOL_CALL_RESULT,
            JSON.stringify(lastOutputBlock.value),
          ] as const)
        : ([
            ATTR_GEN_AI_OUTPUT_MESSAGES,
            JSON.stringify(wrapMessage(outputMsg, lastOutputBlock)),
          ] as const)
      : undefined

  const lastCorrelationId =
    lastOutputBlock?.category === "tool"
      ? lastOutputBlock.correlationId
      : undefined

  const inputEntry = blocks.find(([, block]) => {
    if (block.category === "tool") {
      return (
        block.correlationId === lastCorrelationId ||
        (isOrphanedLeaf && block.type === "input")
      )
    }
    return (
      block.type === "input" ||
      (block.category === "agent-text" && block !== lastOutputBlock)
    )
  })

  const inputAttr = inputEntry
    ? (() => {
        const [inputMsg, firstInputBlock] = inputEntry
        return firstInputBlock.category === "tool"
          ? ([
              ATTR_GEN_AI_TOOL_CALL_ARGUMENTS,
              JSON.stringify(firstInputBlock.value),
            ] as const)
          : ([
              ATTR_GEN_AI_INPUT_MESSAGES,
              JSON.stringify(wrapMessage(inputMsg, firstInputBlock)),
            ] as const)
      })()
    : undefined

  return { inputAttr, outputAttr }
}

const isLeaf = (g: Grouped): g is LeafGrouped => g.depthFromLeaf === 0

const sharedAttrs = (ctx: Ctx): Attributes => ({
  [ATTR_USER_ID]: ctx.userId,
  [ATTR_GEN_AI_CONVERSATION_ID]: ctx.sessionId,
})

const aggregateAttrs = (
  kind: GroupedKind,
  blocks: readonly SourcedBlock[],
): Attributes => {
  const assistants = uniqueAssistants(blocks)
  const model = assistants.at(-1)?.message.model
  const responseId = assistants.at(-1)?.message.id
  const finishReasons =
    kind === GEN_AI_OPERATION_NAME_VALUE_CHAT
      ? assistants.map((m) => m.message.stop_reason).filter((r) => r != null)
      : []
  return {
    ...(model
      ? {
          [ATTR_GEN_AI_REQUEST_MODEL]: model,
          [ATTR_GEN_AI_RESPONSE_MODEL]: model,
        }
      : {}),
    ...(responseId ? { [ATTR_GEN_AI_RESPONSE_ID]: responseId } : {}),
    ...(finishReasons.length
      ? { [ATTR_GEN_AI_RESPONSE_FINISH_REASONS]: finishReasons }
      : {}),
  }
}

const leaf = (
  blocks: readonly [SourcedBlock, ...SourcedBlock[]],
  ctx: Ctx,
  orphaned?: "tool_use" | "tool_result",
): LeafGrouped => {
  const kind = blocks[0][1].kind
  const [startMsg, firstBlock] = blocks[0]
  const isOperation = firstBlock.category === "tool"

  type ToolBlock = Extract<SourcedBlock[1], { category: "tool" }>
  const toolBlock = blocks
    .map(([, b]) => b)
    .find((b): b is ToolBlock => b.category === "tool")
  const toolError = blocks
    .map(([, b]) => (b.category === "tool" && b.error ? b.error : undefined))
    .find((e) => e)

  const times = blocks.map(([m]) => m[META].timestamp.getTime())
  const { inputAttr, outputAttr } = computeIoAttrs(blocks, !!orphaned)

  return {
    kind,
    spanName: toolBlock?.toolName
      ? `execute_tool ${toolBlock.toolName}`
      : startMsg.type,
    spanKind: isOperation ? otelKind(kind) : SpanKind.INTERNAL,
    startTime: Math.min(...times),
    endTime: Math.max(...times),
    attributes: {
      ...sharedAttrs(ctx),
      ...(isOperation ? { [ATTR_GEN_AI_OPERATION_NAME]: kind } : {}),
      ...aggregateAttrs(kind, blocks),
      [metadata("transcript_jq")]: startMsg[META].debugExpr,
      [metadata("block_types")]: blocks.map(([, b]) => b[META].block),
      ...(orphaned ? { [metadata("orphaned")]: orphaned } : {}),
      ...(toolBlock?.toolName
        ? { [ATTR_GEN_AI_TOOL_NAME]: toolBlock.toolName }
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

const branch = (
  kind: GroupedKind,
  partialAttrs: Attributes,
  children: readonly Grouped[],
  ctx: Ctx,
): BranchGrouped | undefined => {
  if (!children.length) {
    return undefined
  }
  const blocks = children.flatMap((c) => c.blocks)
  if (!blocks.length) {
    return undefined
  }

  const aggregates = aggregateAttrs(kind, blocks)
  const agentName = partialAttrs[ATTR_GEN_AI_AGENT_NAME]
  const target =
    kind === GEN_AI_OPERATION_NAME_VALUE_CHAT
      ? aggregates[ATTR_GEN_AI_RESPONSE_MODEL]
      : kind === GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT &&
          typeof agentName === "string"
        ? agentName
        : undefined

  const { inputAttr, outputAttr } = computeIoAttrs(blocks, false)

  return {
    kind,
    spanName: [kind, target].filter((n) => n).join(" "),
    spanKind: otelKind(kind),
    startTime: Math.min(...children.map((c) => c.startTime)),
    endTime: Math.max(...children.map((c) => c.endTime)),
    attributes: {
      ...sharedAttrs(ctx),
      [ATTR_GEN_AI_OPERATION_NAME]: kind,
      ...aggregates,
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
      yield leaf([entry], ctx)
      continue
    }

    const id = block.correlationId
    if (block.type === "input") {
      acc.set(id, entry)
      continue
    }

    const mate = acc.get(id)
    if (mate === undefined) {
      yield leaf([entry], ctx, "tool_result")
      continue
    }
    acc.delete(id)
    yield leaf([mate, entry], ctx)
  }

  for (const entry of acc.values()) {
    yield leaf([entry], ctx, "tool_use")
  }

  return
}

const groupBuffer = (kind: GroupedKind, attributes: Attributes, ctx: Ctx) => {
  const acc = new Array<Grouped>()
  return {
    push: (...group: Grouped[]) => acc.push(...group),
    pop: function* (): IteratorObject<Grouped> {
      if (acc.length === 1) {
        yield* acc
      } else if (acc.length) {
        const wrapped = branch(kind, attributes, [...acc], ctx)
        if (wrapped) yield wrapped
      }
      acc.length = 0
      return
    },
  }
}

const generationId = (grouped: Grouped): string | undefined => {
  for (const [msg] of grouped.blocks) {
    if ("message" in msg && "id" in msg.message) {
      return msg.message.id
    }
  }
  return undefined
}

const groupByGeneration = function* (
  entries: IteratorObject<Grouped>,
  ctx: Ctx,
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
    if (seen.has(genId) || !seen.add(genId)) {
      continue
    }

    const children = (buckets.get(genId) ?? []).map((c) => c.entry)
    if (children.length === 1) {
      yield* children
      continue
    }
    const wrapped = branch(GEN_AI_OPERATION_NAME_VALUE_CHAT, {}, children, ctx)
    if (wrapped) yield wrapped
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
  const acc = groupBuffer(
    GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
    { [ATTR_GEN_AI_AGENT_NAME]: "claude-code" },
    ctx,
  )

  for (const entry of entries) {
    if (isTurnStart(entry)) {
      yield* acc.pop()
    }
    acc.push(entry)
  }
  yield* acc.pop()
  return
}

const groupAgents = function* (
  hook: HookInput,
  entries: IteratorObject<Grouped>,
  ctx: Ctx,
): IteratorObject<Grouped> {
  if (hook.hook_event_name === "SubagentStop") {
    const wrapped = branch(
      GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
      {
        [ATTR_GEN_AI_AGENT_NAME]: hook.agent_type,
        [ATTR_GEN_AI_AGENT_ID]: hook.agent_id,
      },
      entries.toArray(),
      ctx,
    )
    if (wrapped) yield wrapped
    return
  }

  yield* groupTurns(entries, ctx)
  return
}

const emit = (tracer: Tracer, parentCtx: Context, grouped: Grouped): void => {
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
      emit(tracer, childCtx, child)
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

  const transcriptRows = await Array.fromAsync(parseMessages(hook, state.uuid))
  const ctx = { userId, sessionId: hook.session_id } satisfies Ctx
  const extracted = extractContent(transcriptRows.values())
  const correlated = correlateToolCalls(extracted, ctx)
  const generations = groupByGeneration(correlated, ctx)
  const grouped = groupAgents(hook, generations, ctx)

  const tracer = otel.provider.getTracer("claude-code")
  for (const group of grouped) {
    emit(tracer, ROOT_CONTEXT, group)
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
