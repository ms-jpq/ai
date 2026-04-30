#!/usr/bin/env -S -- node

import type { HookInput, SDKMessage } from "@anthropic-ai/claude-agent-sdk"
import type {
  BetaContentBlock,
  BetaContentBlockParam,
  BetaDocumentBlock,
  BetaMessageParam,
  BetaRequestDocumentBlock,
} from "@anthropic-ai/sdk/resources/beta/messages/messages.js"
import type { Attributes, Context, Span, Tracer } from "@opentelemetry/api"
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
  attributes: Attributes
}>

type LeafGrouped = BaseGrouped &
  Readonly<{
    depthFromLeaf: 0
    children: readonly SourcedBlock[]
  }>

type BranchGrouped = BaseGrouped &
  Readonly<{
    depthFromLeaf: number
    children: readonly Grouped[]
  }>

type Grouped = LeafGrouped | BranchGrouped

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

  const types = new Set(["user", "assistant"] as const)

  let found = lastUuid === undefined
  for await (const message of readJsonL(transcriptPath)) {
    if (!found) {
      found ||= message.uuid === lastUuid
      continue
    }
    if (!types.has(message.type)) {
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
    return {
      category: textCategory,
      type: side,
      kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
      value: block,
    }
  }

  switch (block.type) {
    case "text":
      return {
        category: textCategory,
        type: side,
        kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
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
        kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
        value: block.thinking,
      }
    case "redacted_thinking":
      if (!block.data) {
        return undefined
      }
      return {
        category: "agent-thinking",
        type: side,
        kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
        value: block.data,
      }
    case "compaction":
      if (!block.content) {
        return undefined
      }
      return {
        category: textCategory,
        type: side,
        kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
        value: block.content,
      }
    case "image":
      return {
        category: textCategory,
        type: side,
        kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
        value: imageValue(block),
      }

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

const leaf = (
  children: readonly [SourcedBlock, ...SourcedBlock[]],
  orphaned?: "tool_use" | "tool_result",
): Grouped => ({
  kind: children[0][1].kind,
  attributes: orphaned ? { [metadata("orphaned")]: orphaned } : {},
  depthFromLeaf: 0,
  children,
})

const correlateToolCalls = function* (
  extracted: IteratorObject<SourcedBlock>,
): IteratorObject<Grouped> {
  const acc = new Map<string, SourcedBlock>()

  for (const entry of extracted) {
    const [, block] = entry

    if (block.category !== "tool" || block.correlationId === undefined) {
      yield leaf([entry])
      continue
    }

    const id = block.correlationId
    if (block.type === "input") {
      acc.set(id, entry)
      continue
    }

    const mate = acc.get(id)
    if (mate === undefined) {
      yield leaf([entry], "tool_result")
      continue
    }
    acc.delete(id)
    yield leaf([mate, entry])
  }

  for (const entry of acc.values()) {
    yield leaf([entry], "tool_use")
  }

  return
}

const isLeaf = (g: Grouped): g is LeafGrouped => g.depthFromLeaf === 0

const iterGrouped = function* (grouped: Grouped): IteratorObject<SourcedBlock> {
  if (isLeaf(grouped)) {
    yield* grouped.children
    return
  }
  for (const child of grouped.children) {
    yield* iterGrouped(child)
  }
  return
}

const groupBuffer = (kind: GroupedKind, attributes: Attributes = {}) => {
  const acc = new Array<Grouped>()
  return {
    push: (...group: Grouped[]) => acc.push(...group),
    pop: function* (flatten = false): IteratorObject<Grouped> {
      if (acc.length) {
        if (acc.length === 1 || flatten) {
          yield* acc
        } else {
          yield {
            kind,
            attributes,
            depthFromLeaf: 1 + Math.max(...acc.map((a) => a.depthFromLeaf)),
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
    if ("message" in msg && "id" in msg.message) {
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
    if (seen.has(genId) || !seen.add(genId)) {
      continue
    }

    const children = (buckets.get(genId) ?? []).map((c) => c.entry)
    if (children.length === 1) {
      yield* children
      continue
    }
    yield {
      kind: GEN_AI_OPERATION_NAME_VALUE_CHAT,
      attributes: {},
      depthFromLeaf: 1 + Math.max(...children.map((c) => c.depthFromLeaf)),
      children,
    }
  }

  return
}

const isTurnStart = (entry: Grouped): boolean => {
  if (!isLeaf(entry)) {
    return false
  }
  const [first] = entry.children
  if (!first) {
    return false
  }
  const [msg, block] = first
  return msg.type === "user" && block.category !== "tool"
}

const groupTurns = function* (
  entries: IteratorObject<Grouped>,
): IteratorObject<Grouped> {
  const acc = groupBuffer(GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT, {
    [ATTR_GEN_AI_AGENT_NAME]: "claude-code",
  })

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
    const children = entries.toArray()
    yield {
      kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
      attributes: {
        [ATTR_GEN_AI_AGENT_NAME]: hook.agent_type,
        [ATTR_GEN_AI_AGENT_ID]: hook.agent_id,
      },
      depthFromLeaf: 1 + Math.max(...children.map((c) => c.depthFromLeaf), 0),
      children,
    }
    return
  }

  yield* groupTurns(entries)
  return
}

const metadata = (label: string) => `langfuse.observation.metadata.${label}`

const messagePart = (block: ExtractedBlock) => ({
  type: block.category === "agent-thinking" ? "reasoning" : "text",
  content:
    typeof block.value === "string" ? block.value : JSON.stringify(block.value),
})

const wrapInput = (msg: TranscriptMessage, block: ExtractedBlock) => [
  { role: msg.type, parts: [messagePart(block)] },
]

const wrapOutput = (msg: TranscriptMessage, block: ExtractedBlock) => [
  {
    role: msg.type,
    parts: [messagePart(block)],
    finish_reason:
      msg.type === "assistant" ? (msg.message.stop_reason ?? "stop") : "stop",
  },
]

const attachIO = ({ span, grouped }: { span: Span; grouped: Grouped }) => {
  const sourceBlocks = iterGrouped(grouped).toArray()
  const output = sourceBlocks.findLast(([, block]) => block.type === "output")
  const [outputMsg, lastOutputBlock] = output ?? []

  if (lastOutputBlock && outputMsg) {
    if (lastOutputBlock.category === "tool") {
      span.setAttribute(
        ATTR_GEN_AI_TOOL_CALL_RESULT,
        JSON.stringify(lastOutputBlock.value),
      )
    } else {
      span.setAttribute(
        ATTR_GEN_AI_OUTPUT_MESSAGES,
        JSON.stringify(wrapOutput(outputMsg, lastOutputBlock)),
      )
    }
  }

  const lastCorrelationId =
    lastOutputBlock?.category === "tool"
      ? lastOutputBlock.correlationId
      : undefined

  const isOrphanedLeaf =
    isLeaf(grouped) && metadata("orphaned") in grouped.attributes

  const inputEntry = sourceBlocks.find(([, block]) => {
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

  if (inputEntry) {
    const [inputMsg, firstInputBlock] = inputEntry
    if (firstInputBlock.category === "tool") {
      span.setAttribute(
        ATTR_GEN_AI_TOOL_CALL_ARGUMENTS,
        JSON.stringify(firstInputBlock.value),
      )
    } else {
      span.setAttribute(
        ATTR_GEN_AI_INPUT_MESSAGES,
        JSON.stringify(wrapInput(inputMsg, firstInputBlock)),
      )
    }
  }
}

type AssistantMessage = Extract<TranscriptMessage, { type: "assistant" }>

const assistantMessages = (grouped: Grouped): AssistantMessage[] => {
  const seen = new Set<string>()
  return iterGrouped(grouped)
    .map(([m]) => m)
    .filter(
      (m): m is AssistantMessage =>
        m.type === "assistant" && !seen.has(m.uuid) && !!seen.add(m.uuid),
    )
    .toArray()
}

const findModel = (grouped: Grouped): string | undefined =>
  assistantMessages(grouped)
    .map((m) => m.message.model)
    .at(-1)

const findResponseId = (grouped: Grouped): string | undefined =>
  assistantMessages(grouped)
    .map((m) => m.message.id)
    .at(-1)

const findFinishReasons = (grouped: Grouped): string[] =>
  assistantMessages(grouped)
    .map((m) => m.message.stop_reason)
    .filter((r) => r != null)

const findToolError = (grouped: Grouped): string | undefined => {
  for (const [, block] of iterGrouped(grouped)) {
    if (block.category === "tool" && block.error) {
      return block.error
    }
  }
  return undefined
}

const otelKind = (kind: GroupedKind): SpanKind =>
  kind === GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL
    ? SpanKind.INTERNAL
    : SpanKind.CLIENT

type SpanInfo = {
  spanName: string
  spanKind: SpanKind
  operationName: string | undefined
  toolError: string | undefined
  leafAttrs: Attributes
}

const leafInfo = (grouped: LeafGrouped): SpanInfo | undefined => {
  const first = grouped.children[0]
  if (!first) {
    return undefined
  }
  const [startMsg, firstBlock] = first
  const isOperation = firstBlock.category === "tool"
  type ToolBlock = Extract<SourcedBlock[1], { category: "tool" }>
  const toolBlock = grouped.children
    .map(([, b]) => b)
    .find((b): b is ToolBlock => b.category === "tool")
  const toolError = findToolError(grouped)

  return {
    spanName: toolBlock?.toolName
      ? `execute_tool ${toolBlock.toolName}`
      : startMsg.type,
    spanKind: isOperation ? otelKind(grouped.kind) : SpanKind.INTERNAL,
    operationName: isOperation ? grouped.kind : undefined,
    toolError,
    leafAttrs: {
      [metadata("transcript_jq")]: startMsg[META].debugExpr,
      [metadata("block_types")]: grouped.children.map(([, b]) => b[META].block),
      ...(toolBlock?.toolName
        ? { [ATTR_GEN_AI_TOOL_NAME]: toolBlock.toolName }
        : {}),
      ...(toolBlock?.correlationId
        ? { [ATTR_GEN_AI_TOOL_CALL_ID]: toolBlock.correlationId }
        : {}),
      ...(toolError ? { [ATTR_ERROR_TYPE]: toolError } : {}),
    },
  }
}

const branchInfo = (
  grouped: BranchGrouped,
  model: string | undefined,
): SpanInfo => {
  const agentName = grouped.attributes[ATTR_GEN_AI_AGENT_NAME]
  const target =
    grouped.kind === GEN_AI_OPERATION_NAME_VALUE_CHAT
      ? model
      : grouped.kind === GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT &&
          typeof agentName === "string"
        ? agentName
        : undefined
  return {
    spanName: [grouped.kind, target].filter((n) => n).join(" "),
    spanKind: otelKind(grouped.kind),
    operationName: grouped.kind,
    toolError: undefined,
    leafAttrs: {},
  }
}

const emit = ({
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
  const times = iterGrouped(grouped)
    .map(([m]) => m[META].timestamp.getTime())
    .toArray()
  if (!times.length) {
    return
  }

  const model = findModel(grouped)
  const responseId = findResponseId(grouped)
  const finishReasons =
    grouped.kind === GEN_AI_OPERATION_NAME_VALUE_CHAT
      ? findFinishReasons(grouped)
      : []

  const info = isLeaf(grouped) ? leafInfo(grouped) : branchInfo(grouped, model)
  if (!info) {
    return
  }

  const span = tracer.startSpan(
    info.spanName,
    {
      startTime: Math.min(...times),
      kind: info.spanKind,
      attributes: {
        [ATTR_USER_ID]: userId,
        [ATTR_GEN_AI_CONVERSATION_ID]: sessionId,
        ...(info.operationName
          ? { [ATTR_GEN_AI_OPERATION_NAME]: info.operationName }
          : {}),
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
        ...grouped.attributes,
        ...info.leafAttrs,
      },
    },
    parentCtx,
  )

  if (info.toolError) {
    span.setStatus({ code: SpanStatusCode.ERROR })
  }

  if (!isLeaf(grouped)) {
    const childCtx = trace.setSpan(parentCtx, span)
    for (const child of grouped.children) {
      emit({ tracer, parentCtx: childCtx, userId, sessionId, grouped: child })
    }
  }

  attachIO({ span, grouped })
  span.end(Math.max(...times))
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

  const tracer = otel.provider.getTracer("claude-code")
  for (const group of grouped) {
    emit({
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
