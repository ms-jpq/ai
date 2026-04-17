#!/usr/bin/env -S -- node

import type { HookInput, SessionMessage } from "@anthropic-ai/claude-agent-sdk"
import {
  getSessionMessages,
  getSubagentMessages,
} from "@anthropic-ai/claude-agent-sdk"
import type { BetaContentBlock } from "@anthropic-ai/sdk/resources/beta/messages/messages.js"
import type { ContentBlockParam } from "@anthropic-ai/sdk/resources/messages/messages.js"
import {
  MimeType,
  OpenInferenceSpanKind,
  SemanticConventions,
} from "@arizeai/openinference-semantic-conventions"
import type { Link } from "@opentelemetry/api"
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

type Conf = { auth: string; host: string }
type Block = string | BetaContentBlock | ContentBlockParam
type Message = SessionMessage & {
  message: { content: string | Block[] }
  timestamp: string
}
type Role = SessionMessage["type"]
type Slot = "input" | "output" | "error"
type Extracted = {
  type: Slot
  kind: OpenInferenceSpanKind
  value: unknown
}

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

const defer = <T extends { end: () => void }>(
  span: T,
): Disposable & { span: T } => ({
  span,
  [Symbol.dispose]() {
    span.end()
  },
})

const contents = function* ({ message }: Message): IteratorObject<Block> {
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

const extract = (role: Role, block: Block): Extracted | undefined => {
  const side = role === "assistant" ? "output" : "input"

  if (typeof block === "string") {
    return { type: side, kind: OpenInferenceSpanKind.LLM, value: block }
  }

  switch (block.type) {
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
        default:
          fail(block.source satisfies never)
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
        default:
          fail(block.source satisfies never)
      }

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

    case "text":
      return { type: side, kind: OpenInferenceSpanKind.LLM, value: block.text }
    case "compaction":
      return {
        type: side,
        kind: OpenInferenceSpanKind.LLM,
        value: block.content ?? "",
      }

    case "mcp_tool_use":
      return {
        type: "output",
        kind: OpenInferenceSpanKind.TOOL,
        value: {
          name: block.name,
          input: block.input,
          server_name: block.server_name,
        },
      }

    case "server_tool_use":
    case "tool_use":
      return {
        type: "output",
        kind: OpenInferenceSpanKind.TOOL,
        value: { name: block.name, input: block.input },
      }

    case "code_execution_tool_result":
    case "bash_code_execution_tool_result":
      switch (block.content.type) {
        case "bash_code_execution_tool_result_error":
        case "code_execution_tool_result_error":
          return {
            type: "error",
            kind: OpenInferenceSpanKind.TOOL,
            value: block.content.error_code,
          }
        case "encrypted_code_execution_result":
          return {
            type: "output",
            kind: OpenInferenceSpanKind.TOOL,
            value: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
            },
          }
        case "bash_code_execution_result":
        case "code_execution_result":
          return {
            type: "output",
            kind: OpenInferenceSpanKind.TOOL,
            value: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
              stdout: block.content.stdout,
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "mcp_tool_result":
    case "tool_result":
      if (block.is_error) {
        return {
          type: "error",
          kind: OpenInferenceSpanKind.TOOL,
          value: block.content,
        }
      }
      return {
        type: "output",
        kind: OpenInferenceSpanKind.TOOL,
        value: block.content,
      }

    case "search_result":
      return {
        type: "output",
        kind: OpenInferenceSpanKind.RETRIEVER,
        value: {
          content: block.content,
          source: block.source,
          title: block.title,
        },
      }

    case "text_editor_code_execution_tool_result":
      switch (block.content.type) {
        case "text_editor_code_execution_tool_result_error":
          return {
            type: "error",
            kind: OpenInferenceSpanKind.TOOL,
            value: {
              error_code: block.content.error_code,
              error_message: block.content.error_message,
            },
          }
        case "text_editor_code_execution_view_result":
          return {
            type: side,
            kind: OpenInferenceSpanKind.TOOL,
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
            type: "output",
            kind: OpenInferenceSpanKind.TOOL,
            value: { is_file_update: block.content.is_file_update },
          }
        case "text_editor_code_execution_str_replace_result":
          return {
            type: "output",
            kind: OpenInferenceSpanKind.TOOL,
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
            type: "error",
            kind: OpenInferenceSpanKind.TOOL,
            value: rest,
          }
        }
        case "tool_search_tool_search_result":
          return {
            type: "output",
            kind: OpenInferenceSpanKind.TOOL,
            value: block.content.tool_references,
          }
        default:
          fail(block.content satisfies never)
      }

    case "web_search_tool_result":
      if (Array.isArray(block.content)) {
        return {
          type: "output",
          kind: OpenInferenceSpanKind.RETRIEVER,
          value: block.content.map((r) => ({
            page_age: r.page_age,
            title: r.title,
            url: r.url,
          })),
        }
      }
      return {
        type: "error",
        kind: OpenInferenceSpanKind.RETRIEVER,
        value: block.content.error_code,
      }

    case "web_fetch_tool_result":
      switch (block.content.type) {
        case "web_fetch_tool_result_error":
          return {
            type: "error",
            kind: OpenInferenceSpanKind.RETRIEVER,
            value: block.content.error_code,
          }
        case "web_fetch_result":
          return {
            type: "output",
            kind: OpenInferenceSpanKind.RETRIEVER,
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

const isEmpty = (v: unknown): boolean => {
  if (v === undefined || v === null || v === "") {
    return true
  }
  if (Array.isArray(v)) {
    return v.every(isEmpty)
  }
  if (typeof v === "object") {
    return Object.values(v).every(isEmpty)
  }
  return false
}

const VALUE_KEY = {
  input: SemanticConventions.INPUT_VALUE,
  output: SemanticConventions.OUTPUT_VALUE,
  error: SemanticConventions.OUTPUT_VALUE,
} as const satisfies Record<Extracted["type"], string>

const MIME_KEY = {
  input: SemanticConventions.INPUT_MIME_TYPE,
  output: SemanticConventions.OUTPUT_MIME_TYPE,
  error: SemanticConventions.OUTPUT_MIME_TYPE,
} as const satisfies Record<Extracted["type"], string>

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
  await using otel = provider(config)

  const opts = { offset: state.offset }
  const messages = (await (isSub
    ? getSubagentMessages(hook.session_id, hook.agent_id, opts)
    : getSessionMessages(hook.session_id, opts))) as Message[]

  log({ level: "debug", msg: `messages: ${messages.length}` })

  const tracer = otel.provider.getTracer("langfuse-sdk")

  const traceName = `[${hook.session_id}] - ${hook.hook_event_name}`
  const attributes = {
    [SemanticConventions.USER_ID]: userId,
    [SemanticConventions.SESSION_ID]: hook.session_id,
    [SemanticConventions.TAG_TAGS]: ["claude-code"],
  }

  for (const [i, message] of messages.entries()) {
    const startTime = new Date(message.timestamp).getTime()
    const blocks = contents(message)
      .map((b) => extract(message.type, b))
      .filter((b): b is Extracted => b !== undefined && !isEmpty(b.value))
      .toArray()

    let prev: Link | undefined
    for (const [j, block] of blocks.entries()) {
      using span = defer(
        tracer.startSpan(`${traceName}: ${i}.${j}`, {
          startTime,
          attributes,
          links: prev ? [prev] : [],
        }),
      )
      prev = { context: span.span.spanContext() }

      if (block.type === "error") {
        span.span.setStatus({ code: SpanStatusCode.ERROR })
      }
      span.span.setAttributes({
        "message.uuid": message.uuid,
        [MIME_KEY[block.type]]: MimeType.JSON,
        [SemanticConventions.OPENINFERENCE_SPAN_KIND]: block.kind,
        [VALUE_KEY[block.type]]: JSON.stringify(block.value),
      })
    }
  }

  state.offset += messages.length
}

await main()
