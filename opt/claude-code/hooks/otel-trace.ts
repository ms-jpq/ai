#!/usr/bin/env -S -- node

import type { HookInput, SDKMessage } from "@anthropic-ai/claude-agent-sdk"
import type {
  BetaContentBlock,
  BetaContentBlockParam,
  BetaDocumentBlock,
  BetaImageBlockParam,
  BetaMessageParam,
  BetaRequestDocumentBlock,
} from "@anthropic-ai/sdk/resources/beta/messages/messages.js"
import type { Attributes, Context, Tracer } from "@opentelemetry/api"
import { ROOT_CONTEXT, SpanKind, SpanStatusCode, trace } from "@opentelemetry/api"
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-proto"
import {
  defaultResource,
  detectResources,
  hostDetector,
  osDetector,
  processDetector,
  resourceFromAttributes,
} from "@opentelemetry/resources"
import { BasicTracerProvider, BatchSpanProcessor } from "@opentelemetry/sdk-trace-base"
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

type Role = TranscriptMessage["type"]

type BlockKind = typeof GEN_AI_OPERATION_NAME_VALUE_CHAT | typeof GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL

type GroupedKind = BlockKind | typeof GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT

type ExtractedBlockType = typeof GEN_AI_TOKEN_TYPE_VALUE_INPUT | typeof GEN_AI_TOKEN_TYPE_VALUE_OUTPUT

type MessagePart = Readonly<{ type: string } & Record<string, unknown>>

type OtelMessage = Readonly<{
  role: "system" | "user" | "assistant" | "tool"
  parts: readonly MessagePart[]
  finish_reason?: string
}>

type OtelMessageSequence = readonly OtelMessage[]

type ChatBlock = Readonly<{
  category: "chat"
  role: Role
  type: ExtractedBlockType
  part: MessagePart
}>

type ToolBlock = Readonly<{
  category: "tool"
  type: ExtractedBlockType
  kind: BlockKind
  value: unknown
  correlationId: string | undefined
  toolName?: string
  toolType?: "function" | "extension"
  error?: string
}>

type ExtractedBlock = ChatBlock | ToolBlock

type SourcedBlock<T extends ExtractedBlock> = Readonly<{ msg: TranscriptMessage; block: T }>

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
  attributes: Readonly<
    Attributes & {
      [ATTR_GEN_AI_INPUT_MESSAGES]?: string
      [ATTR_GEN_AI_OUTPUT_MESSAGES]?: string
    }
  >
  status?: { code: SpanStatusCode }
  children?: readonly Grouped[]
  [META]: {
    turnStart?: boolean
    inputSequence?: OtelMessageSequence
    outputSequence?: OtelMessageSequence
  }
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

const measure = (label: string): Disposable => {
  const procT0 = performance.now()
  console.error(`[debug] ${label} started`)

  return {
    [Symbol.dispose]() {
      const elapsed = ((performance.now() - procT0) / 1000).toFixed(2)
      console.error(`[info] ${label} completed in ${elapsed}s`)
    },
  }
}

const openState = async (hook: HookInput): Promise<AsyncDisposable & { uuid?: string }> => {
  const key = hook.hook_event_name === "SubagentStop" ? `${hook.session_id}.${hook.agent_id}` : hook.session_id
  const path = resolve(SESSIONS_DIR, `${key}.openinference.uuid`)
  const tmp = `${path}.${randomUUID()}.tmp`

  const uuid = (await readFile(path, "utf-8").catch(() => "")).trim() || undefined
  const state = {
    uuid,
    async [Symbol.asyncDispose]() {
      await mkdir(dirname(path), { recursive: true })
      await writeFile(tmp, state.uuid ?? "", "utf-8")
      await rename(tmp, path)
    },
  }
  return state
}

const provider = (hook: HookInput): (AsyncDisposable & { provider: BasicTracerProvider }) | undefined => {
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

const readJsonL = async function* (path: string): AsyncIteratorObject<TranscriptMessage> {
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
  const transcriptPath = isSubAgent ? hook.agent_transcript_path : hook.transcript_path

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

const contents = function* (msg: TranscriptMessage): IteratorObject<MessageBlock> {
  const content = msg.message.content
  if (typeof content === "string") {
    yield content
  } else if (Array.isArray(content)) {
    yield* content
  }

  return
}

const extractChat = ({ role, part }: { role: Role; part: MessagePart }) =>
  ({
    category: "chat",
    role,
    type: role === "assistant" ? GEN_AI_TOKEN_TYPE_VALUE_OUTPUT : GEN_AI_TOKEN_TYPE_VALUE_INPUT,
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
  error,
}: {
  correlationId: string
  value: unknown
  error?: string
}) =>
  ({
    category: "tool",
    type: GEN_AI_TOKEN_TYPE_VALUE_OUTPUT,
    kind: GEN_AI_OPERATION_NAME_VALUE_EXECUTE_TOOL,
    correlationId,
    value,
    ...(error !== undefined ? { error } : {}),
  }) satisfies ExtractedBlock

const documentPart = ({ source, ...block }: BetaRequestDocumentBlock): MessagePart => {
  const meta = {
    ...(block.title ? { title: block.title } : {}),
    ...(block.context ? { context: block.context } : {}),
  }
  switch (source.type) {
    case "base64":
    case "text":
      return { type: "document", mime_type: source.media_type, ...meta }
    case "url":
      return { type: "document", uri: source.url, ...meta }
    case "file":
      return { type: "document", file_id: source.file_id, ...meta }
    case "content":
      return { type: "document", ...meta }
    default:
      fail(source satisfies never)
  }
}

const documentValue = ({ source, title, ...block }: BetaDocumentBlock | BetaRequestDocumentBlock) => {
  const context = "context" in block ? block.context : undefined
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

const imagePart = ({ source }: BetaImageBlockParam): MessagePart => {
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

const imageValue = ({ source }: { source: BetaImageBlockParam["source"] }) => {
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

const extractBlock = (role: Role, block: MessageBlock): ExtractedBlock | undefined => {
  if (typeof block === "string") {
    return extractChat({ role, part: { type: "text", content: block } })
  }

  switch (block.type) {
    case "text":
      return extractChat({
        role,
        part: {
          type: "text",
          content: block.text,
          ...(block.citations?.length ? { citations: block.citations } : {}),
        },
      })
    case "thinking":
      return block.thinking
        ? extractChat({
            role,
            part: { type: "reasoning", content: block.thinking },
          })
        : undefined
    case "redacted_thinking":
      return block.data
        ? extractChat({
            role,
            part: { type: "reasoning", content: block.data },
          })
        : undefined
    case "compaction":
      return block.content
        ? extractChat({
            role,
            part: { type: "text", content: block.content },
          })
        : undefined
    case "image":
      return extractChat({ role, part: imagePart(block) })

    case "mcp_tool_use":
      return extractToolUse({
        toolName: `mcp__${block.server_name}__${block.name}`,
        toolType: "extension",
        correlationId: block.id,
        value: block.input,
      })
    case "server_tool_use":
      return extractChat({
        role,
        part: {
          type: "server_tool_call",
          id: block.id,
          name: block.name,
          server_tool_call: { arguments: block.input },
        },
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
      return extractChat({
        role,
        part: {
          type: "server_tool_call_response",
          id: block.tool_use_id,
          server_tool_call_response: (() => {
            switch (block.content.type) {
              case "bash_code_execution_tool_result_error":
              case "code_execution_tool_result_error":
                return { error_code: block.content.error_code }
              case "encrypted_code_execution_result":
                return {
                  return_code: block.content.return_code,
                  stderr: block.content.stderr,
                }
              case "bash_code_execution_result":
              case "code_execution_result":
                return {
                  return_code: block.content.return_code,
                  stderr: block.content.stderr,
                  stdout: block.content.stdout,
                }
              default:
                fail(block.content satisfies never)
            }
          })(),
        },
      })

    case "text_editor_code_execution_tool_result":
      return extractChat({
        role,
        part: {
          type: "server_tool_call_response",
          id: block.tool_use_id,
          server_tool_call_response: (() => {
            switch (block.content.type) {
              case "text_editor_code_execution_tool_result_error":
                return {
                  error_code: block.content.error_code,
                  error_message: block.content.error_message,
                }
              case "text_editor_code_execution_view_result":
                return {
                  content: block.content.content,
                  file_type: block.content.file_type,
                  num_lines: block.content.num_lines,
                  start_line: block.content.start_line,
                  total_lines: block.content.total_lines,
                }
              case "text_editor_code_execution_create_result":
                return { is_file_update: block.content.is_file_update }
              case "text_editor_code_execution_str_replace_result":
                return {
                  lines: block.content.lines,
                  new_lines: block.content.new_lines,
                  new_start: block.content.new_start,
                  old_lines: block.content.old_lines,
                  old_start: block.content.old_start,
                }
              default:
                fail(block.content satisfies never)
            }
          })(),
        },
      })

    case "tool_search_tool_result":
      return extractChat({
        role,
        part: {
          type: "server_tool_call_response",
          id: block.tool_use_id,
          server_tool_call_response: (() => {
            switch (block.content.type) {
              case "tool_search_tool_result_error": {
                const { type: _, ...rest } = block.content
                return rest
              }
              case "tool_search_tool_search_result":
                return { tool_references: block.content.tool_references }
              default:
                fail(block.content satisfies never)
            }
          })(),
        },
      })

    case "document":
      return extractChat({ role, part: documentPart(block) })
    case "search_result":
      return extractChat({
        role,
        part: {
          type: "search_result",
          content: block.content.map((item) => item.text),
          source: block.source,
          title: block.title,
        },
      })
    case "web_search_tool_result": {
      return extractChat({
        role,
        part: {
          type: "server_tool_call_response",
          id: block.tool_use_id,
          server_tool_call_response: Array.isArray(block.content)
            ? {
                results: block.content.map((r) => ({
                  page_age: r.page_age,
                  title: r.title,
                  url: r.url,
                })),
              }
            : { error_code: block.content.error_code },
        },
      })
    }
    case "web_fetch_tool_result": {
      return extractChat({
        role,
        part: {
          type: "server_tool_call_response",
          id: block.tool_use_id,
          server_tool_call_response: (() => {
            switch (block.content.type) {
              case "web_fetch_tool_result_error":
                return { error_code: block.content.error_code }
              case "web_fetch_result":
                return {
                  retrieved_at: block.content.retrieved_at,
                  url: block.content.url,
                  content: documentValue(block.content.content),
                }
              default:
                fail(block.content satisfies never)
            }
          })(),
        },
      })
    }

    case "container_upload":
      return {
        category: "tool",
        type: role === "assistant" ? GEN_AI_TOKEN_TYPE_VALUE_OUTPUT : GEN_AI_TOKEN_TYPE_VALUE_INPUT,
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

const [normalizeFinishReason, messageFinishReason] = (() => {
  const make = (toolUse: string) => {
    const map = new Map([
      ["end_turn", "stop"],
      ["max_tokens", "length"],
      ["pause_turn", "stop"],
      ["refusal", "content_filter"],
      ["stop_sequence", "stop"],
      ["tool_use", toolUse],
    ])
    return (raw: string | null) => map.get(raw ?? "") ?? raw ?? "stop"
  }
  return [make("tool_calls"), make("tool_call")] as const
})()

const factsFromAssistant = ({ message }: Extract<TranscriptMessage, { type: "assistant" }>): Facts => {
  if (message.model === "<synthetic>") {
    return {
      stopReasons: message.stop_reason ? [message.stop_reason] : [],
    }
  }

  const u = message.usage
  return {
    model: message.model,
    responseId: message.id,
    stopReasons: message.stop_reason ? [message.stop_reason] : [],
    usage: {
      input_tokens: u.input_tokens + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0),
      output_tokens: u.output_tokens,
      cache_read_input_tokens: u.cache_read_input_tokens ?? 0,
      cache_creation_input_tokens: u.cache_creation_input_tokens ?? 0,
    },
  }
}

const commonAttrs = ({ kind, ctx, facts }: { kind: GroupedKind; ctx: Ctx; facts?: Facts }): Attributes => {
  const { model, responseId, stopReasons, usage } = facts ?? {}
  const isApi = kind === GEN_AI_OPERATION_NAME_VALUE_CHAT

  return {
    [ATTR_USER_ID]: ctx.userId,
    [ATTR_GEN_AI_CONVERSATION_ID]: ctx.sessionId,
    [ATTR_GEN_AI_OPERATION_NAME]: kind,
    [ATTR_GEN_AI_PROVIDER_NAME]: GEN_AI_PROVIDER_NAME_VALUE_ANTHROPIC,
    [ATTR_SERVER_ADDRESS]: isApi ? "api.anthropic.com" : undefined,
    [ATTR_GEN_AI_OUTPUT_TYPE]: kind === GEN_AI_OPERATION_NAME_VALUE_CHAT ? GEN_AI_OUTPUT_TYPE_VALUE_TEXT : undefined,
    [ATTR_GEN_AI_REQUEST_MODEL]: model,
    [ATTR_GEN_AI_RESPONSE_MODEL]: model,
    [ATTR_GEN_AI_RESPONSE_ID]: responseId,
    [ATTR_GEN_AI_RESPONSE_FINISH_REASONS]: stopReasons?.length ? stopReasons.map(normalizeFinishReason) : undefined,
    [ATTR_GEN_AI_USAGE_INPUT_TOKENS]: usage?.input_tokens,
    [ATTR_GEN_AI_USAGE_OUTPUT_TOKENS]: usage?.output_tokens,
    [ATTR_GEN_AI_USAGE_CACHE_READ_INPUT_TOKENS]: usage?.cache_read_input_tokens,
    [ATTR_GEN_AI_USAGE_CACHE_CREATION_INPUT_TOKENS]: usage?.cache_creation_input_tokens,
  }
}

const metadata = (label: string) => `langfuse.observation.metadata.${label}`

const toMessages = ({
  sourced,
  asInput,
}: {
  sourced: Iterable<SourcedBlock<ChatBlock>>
  asInput: boolean
}): OtelMessageSequence =>
  Map.groupBy(sourced, (s) => s.msg)
    .entries()
    .map(([msg, items]) => ({
      role: msg.type,
      parts: items.map((s) => s.block.part),
      ...(asInput
        ? {}
        : {
            finish_reason: msg.type === "assistant" ? messageFinishReason(msg.message.stop_reason) : "stop",
          }),
    }))
    .toArray()

const chatLeaf = ({
  ctx,
  input,
  output,
}: {
  ctx: Ctx
  input?: NonEmpty<SourcedBlock<ChatBlock>>
  output?: NonEmpty<SourcedBlock<ChatBlock>>
}): Grouped => {
  const ref = output ?? input
  ok(ref, "chatLeaf needs at least one of input/output")

  const [{ msg: assistantMsg }] = output ?? [{ msg: undefined }]
  const facts = assistantMsg?.type === "assistant" ? factsFromAssistant(assistantMsg) : undefined

  const [first] = input ?? ref
  const last = ref.at(-1)
  ok(last)

  const inputSequence = toMessages({ sourced: input ?? [], asInput: true })
  const outputSequence = toMessages({ sourced: output ?? [], asInput: false })

  return {
    spanName: facts?.model ? `chat ${facts.model}` : "chat",
    spanKind: SpanKind.CLIENT,
    startTime: first.msg[META].timestamp.getTime(),
    endTime: last.msg[META].timestamp.getTime(),
    attributes: {
      ...commonAttrs({ kind: GEN_AI_OPERATION_NAME_VALUE_CHAT, ctx, facts }),
      [ATTR_GEN_AI_INPUT_MESSAGES]: JSON.stringify(inputSequence),
      [ATTR_GEN_AI_OUTPUT_MESSAGES]: JSON.stringify(outputSequence),
      [metadata("transcript_jq")]: last.msg[META].debugExpr,
    },
    [META]: { inputSequence, outputSequence },
  }
}

const otelKind = (kind: GroupedKind): SpanKind =>
  kind === GEN_AI_OPERATION_NAME_VALUE_CHAT ? SpanKind.CLIENT : SpanKind.INTERNAL

const toolLeaf = ({
  ctx,
  input,
  output,
}: {
  ctx: Ctx
  input?: SourcedBlock<ToolBlock>
  output?: SourcedBlock<ToolBlock>
}): Grouped => {
  const ref = input ?? output
  ok(ref, "toolLeaf needs at least one of input/output")

  const block = ref.block
  const error = input?.block.error ?? output?.block.error
  const orphaned = !input ? "tool_result" : !output ? "tool_use" : undefined
  const startTime = (input ?? ref).msg[META].timestamp.getTime()
  const endTime = (output ?? ref).msg[META].timestamp.getTime()
  const kind = block.kind

  const inputSequence = input
    ? ([
        {
          role: "assistant",
          parts: [
            {
              type: "tool_call",
              ...(block.correlationId !== undefined ? { id: block.correlationId } : {}),
              ...(block.toolName ? { name: block.toolName } : {}),
              arguments: input.block.value,
            },
          ],
        },
      ] satisfies OtelMessageSequence)
    : []
  const outputSequence = output
    ? ([
        {
          role: "tool",
          parts: [
            {
              type: "tool_call_response",
              ...(block.correlationId !== undefined ? { id: block.correlationId } : {}),
              response: output.block.value,
            },
          ],
        },
      ] satisfies OtelMessageSequence)
    : []

  return {
    spanName: block.toolName ? `${kind} ${block.toolName}` : kind,
    spanKind: otelKind(kind),
    startTime,
    endTime,
    attributes: {
      ...commonAttrs({ kind, ctx }),
      [ATTR_GEN_AI_TOOL_CALL_ARGUMENTS]: input ? JSON.stringify(input.block.value) : undefined,
      [ATTR_GEN_AI_TOOL_CALL_RESULT]: output ? JSON.stringify(output.block.value) : undefined,
      [ATTR_GEN_AI_INPUT_MESSAGES]: JSON.stringify(inputSequence),
      [ATTR_GEN_AI_OUTPUT_MESSAGES]: JSON.stringify(outputSequence),
      [ATTR_GEN_AI_TOOL_NAME]: block.toolName,
      [ATTR_GEN_AI_TOOL_TYPE]: block.toolType,
      [ATTR_GEN_AI_TOOL_CALL_ID]: block.correlationId,
      [ATTR_ERROR_TYPE]: error,
      [metadata("transcript_jq")]: ref.msg[META].debugExpr,
      [metadata("orphaned")]: orphaned,
    },
    status: error ? { code: SpanStatusCode.ERROR } : undefined,
    [META]: { inputSequence, outputSequence },
  }
}

const buildLeaves = function* ({
  ctx,
  transcript,
}: {
  ctx: Ctx
  transcript: IteratorObject<TranscriptMessage>
}): IteratorObject<Grouped> {
  const toolCalls = new Map<string, SourcedBlock<ToolBlock>>()
  const chatInputs = new Array<SourcedBlock<ChatBlock>>()
  const chatOutputs = new Array<SourcedBlock<ChatBlock>>()

  let turnStart = false
  const markTurnStart = (grouped: Grouped): Grouped => {
    if (!turnStart) {
      return grouped
    }
    turnStart = false
    const { [META]: meta, ...g } = grouped
    return { ...g, [META]: { ...meta, turnStart: true } }
  }

  const emitChat = function* (): IteratorObject<Grouped> {
    const drainedIn = chatInputs.splice(0)
    const drainedOut = chatOutputs.splice(0)
    const input = isNonEmpty(drainedIn) ? drainedIn : undefined
    const output = isNonEmpty(drainedOut) ? drainedOut : undefined
    if (input || output) {
      yield markTurnStart(chatLeaf({ input, output, ctx }))
    }
    return
  }

  for (const msg of transcript) {
    const blocks = contents(msg)
      .map((raw) => extractBlock(msg.type, raw))
      .filter((b) => b !== undefined)

    if (msg.type === "user") {
      turnStart = true
    }

    for (const block of blocks) {
      if (block.category === "tool") {
        yield* emitChat()

        const sourced = { msg, block }

        if (block.correlationId === undefined) {
          yield toolLeaf({ input: sourced, ctx })
          continue
        }

        if (block.type === GEN_AI_TOKEN_TYPE_VALUE_INPUT) {
          toolCalls.set(block.correlationId, sourced)
          continue
        }

        const input = toolCalls.get(block.correlationId)
        toolCalls.delete(block.correlationId)
        yield markTurnStart(toolLeaf({ input, output: sourced, ctx }))
        continue
      }

      const sourced = { msg, block }
      if (block.type === GEN_AI_TOKEN_TYPE_VALUE_INPUT) {
        if (chatOutputs.length > 0) {
          yield* emitChat()
        }
        chatInputs.push(sourced)
        continue
      }

      chatOutputs.push(sourced)
    }
  }

  yield* emitChat()

  for (const orphan of toolCalls.values()) {
    yield toolLeaf({ input: orphan, ctx })
  }
  return
}

const buildBranch = ({
  ctx,
  kind,
  attributes,
  children,
}: {
  ctx: Ctx
  kind: GroupedKind
  attributes: Attributes
  children: NonEmpty<Grouped>
}): Grouped => {
  const agentName = attributes[ATTR_GEN_AI_AGENT_NAME]
  const target = typeof agentName === "string" ? agentName : undefined

  const inputSequence = children.flatMap((c) => c[META].inputSequence ?? [])
  const outputSequence = children.flatMap((c) => c[META].outputSequence ?? [])

  return {
    spanName: [kind, target].filter((n) => n).join(" "),
    spanKind: otelKind(kind),
    startTime: Math.min(...children.map((c) => c.startTime)),
    endTime: Math.max(...children.map((c) => c.endTime)),
    attributes: {
      ...commonAttrs({ kind, ctx }),
      [ATTR_GEN_AI_INPUT_MESSAGES]: JSON.stringify(inputSequence),
      [ATTR_GEN_AI_OUTPUT_MESSAGES]: JSON.stringify(outputSequence),
      ...attributes,
    },
    children,
    [META]: { inputSequence, outputSequence },
  }
}

const groupAgents = function* ({
  ctx,
  hook,
  leaves,
}: {
  ctx: Ctx
  hook: HookInput
  leaves: IteratorObject<Grouped>
}): IteratorObject<Grouped> {
  if (hook.hook_event_name === "SubagentStop") {
    const children = leaves.toArray()
    if (!isNonEmpty(children)) {
      return
    }

    yield buildBranch({
      kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
      attributes: {
        [ATTR_GEN_AI_AGENT_NAME]: hook.agent_type,
        [ATTR_GEN_AI_AGENT_ID]: hook.agent_id,
      },
      children,
      ctx,
    })
    return
  }

  for (const children of chunkBy({
    source: leaves,
    isBoundary: (e) => e[META].turnStart === true,
  })) {
    yield buildBranch({
      ctx,
      kind: GEN_AI_OPERATION_NAME_VALUE_INVOKE_AGENT,
      attributes: {
        [ATTR_GEN_AI_AGENT_NAME]: "general-purpose",
        [ATTR_GEN_AI_AGENT_ID]: hook.session_id,
      },
      children,
    })
  }
  return
}

const emitSpanTree = ({
  tracer,
  parentCtx,
  grouped,
}: {
  tracer: Tracer
  parentCtx: Context
  grouped: Grouped
}): void => {
  const attributes = Object.fromEntries(Object.entries(grouped.attributes).filter(([, v]) => v !== undefined))
  const span = tracer.startSpan(
    grouped.spanName,
    {
      startTime: grouped.startTime,
      kind: grouped.spanKind,
      attributes,
    },
    parentCtx,
  )
  if (grouped.status) {
    span.setStatus(grouped.status)
  }
  if (grouped.children) {
    const childCtx = trace.setSpan(parentCtx, span)
    for (const child of grouped.children) {
      emitSpanTree({ tracer, parentCtx: childCtx, grouped: child })
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
  const leaves = buildLeaves({ ctx, transcript: transcript.values() })
  const grouped = groupAgents({ ctx, hook, leaves })

  const tracer = otel.provider.getTracer("claude-code")
  for (const group of grouped) {
    emitSpanTree({ tracer, parentCtx: ROOT_CONTEXT, grouped: group })
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
