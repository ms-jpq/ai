#!/usr/bin/env -S -- node

import type { HookInput, SessionMessage } from "@anthropic-ai/claude-agent-sdk"
import {
  getSessionMessages,
  getSubagentMessages,
} from "@anthropic-ai/claude-agent-sdk"
import type { BetaContentBlock } from "@anthropic-ai/sdk/resources/beta/messages/messages.js"
import type { ContentBlockParam } from "@anthropic-ai/sdk/resources/messages/messages.js"
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

type Conf = { publicKey: string; secretKey: string; host: string }
type Role = SessionMessage["type"]

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..", "..")
const SESSIONS_DIR = resolve(ROOT, "var", "sessions")

const log = ({
  level,
  msg,
}: {
  level: "debug" | "info" | "error"
  msg: string
}) => {
  if (level === "error") {
    console.error(`[${level}] ${msg}`)
  }
}

const measure = (label: string) => {
  const process = performance.now()
  log({ level: "debug", msg: `${label} started` })

  return {
    jesus: Date.now(),
    process,
    [Symbol.dispose]() {
      const elapsed = ((performance.now() - process) / 1000).toFixed(2)
      log({ level: "info", msg: `${label} completed in ${elapsed}s` })
    },
  }
}

const gitUserName = () =>
  promisify(execFile)("git", ["config", "user.name"])
    .then(({ stdout }) => stdout.trim())
    .catch(() => "")

const conf = (): Conf | undefined => {
  const [publicKey, secretKey, host] = [
    env["LANGFUSE_PUBLIC_KEY"],
    env["LANGFUSE_SECRET_KEY"],
    env["LANGFUSE_BASE_URL"],
  ]

  if (!publicKey || !secretKey || !host) {
    return undefined
  }

  return { publicKey, secretKey, host }
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

const provider = (config: Conf) => {
  const auth = Buffer.from(`${config.publicKey}:${config.secretKey}`).toString(
    "base64",
  )
  const exporter = new OTLPTraceExporter({
    url: join(config.host, `/api/public/otel/v1/traces`),
    headers: { Authorization: `Basic ${auth}` },
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

const defer = <T extends { end: () => void }>(span: T) => ({
  span,
  [Symbol.dispose]() {
    span.end()
  },
})

type Block = string | BetaContentBlock | ContentBlockParam

const contents = function* ({
  message,
}: SessionMessage): IteratorObject<Block> {
  const msg = message as { content: string | Block[] }

  if (typeof msg.content === "string") {
    yield msg.content
  } else {
    yield* msg.content
  }

  return
}

type Extracted =
  | { type: "input"; value: unknown }
  | { type: "output"; value: unknown }
  | { type: "error"; value: unknown }

const extract = (role: Role, block: Block): Extracted | undefined => {
  const side = role === "assistant" ? "output" : "input"

  if (typeof block === "string") {
    return { type: side, value: block }
  }

  switch (block.type) {
    case "compaction":
      return { type: side, value: block.content ?? "" }
    case "text":
      return { type: side, value: block.text }
    case "thinking":
      return { type: side, value: block.thinking }
    case "redacted_thinking":
      return { type: side, value: block.data }

    case "mcp_tool_use":
    case "server_tool_use":
    case "tool_use":
      return {
        type: "output",
        value: { name: block.name, input: block.input },
      }

    case "code_execution_tool_result":
    case "bash_code_execution_tool_result":
      switch (block.content.type) {
        case "bash_code_execution_tool_result_error":
        case "code_execution_tool_result_error":
          return { type: "error", value: block.content.error_code }
        case "encrypted_code_execution_result":
          return {
            type: "output",
            value: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
            },
          }
        case "bash_code_execution_result":
        case "code_execution_result":
          return {
            type: "output",
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
        return { type: "error", value: block.content }
      }
      return { type: "output", value: block.content }

    case "search_result":
      return {
        type: "output",
        value: {
          source: block.source,
          title: block.title,
          content: block.content,
        },
      }

    case "text_editor_code_execution_tool_result":
      switch (block.content.type) {
        case "text_editor_code_execution_tool_result_error":
          return { type: "error", value: block.content }
        case "text_editor_code_execution_view_result":
          return { type: side, value: block.content.content }
        case "text_editor_code_execution_create_result":
          return {
            type: "output",
            value: { is_file_update: block.content.is_file_update },
          }
        case "text_editor_code_execution_str_replace_result":
          return {
            type: "output",
            value: {
              old_start: block.content.old_start,
              old_lines: block.content.old_lines,
              new_start: block.content.new_start,
              new_lines: block.content.new_lines,
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "tool_search_tool_result":
      switch (block.content.type) {
        case "tool_search_tool_result_error":
          return { type: "error", value: block.content.error_code }
        case "tool_search_tool_search_result":
          return { type: "output", value: block.content.tool_references }
        default:
          fail(block.content satisfies never)
      }

    case "web_search_tool_result":
      if (Array.isArray(block.content)) {
        return {
          type: "output",
          value: block.content.map((r) => ({ title: r.title, url: r.url })),
        }
      }
      return { type: "error", value: block.content.error_code }

    case "web_fetch_tool_result":
      switch (block.content.type) {
        case "web_fetch_tool_result_error":
          return { type: "error", value: block.content.error_code }
        case "web_fetch_result":
          return {
            type: "output",
            value: {
              url: block.content.url,
              retrieved_at: block.content.retrieved_at,
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "document":
    case "image":
    case "container_upload":
      return undefined
    default:
      fail(block satisfies never)
  }
}

const jsonValues = (items: Extracted[]) =>
  JSON.stringify(
    items.length === 1 ? items[0]?.value : items.map((b) => b.value),
  )

const annotated = (message: SessionMessage) => {
  const blocks = contents(message)
    .map((b) => extract(message.type, b))
    .filter((b): b is Extracted => b !== undefined)
  const group = Map.groupBy(blocks, (b) => b.type)
  const gm = group
    .entries()
    .map(([k, v]) => [k, jsonValues(v)] as const)
    .filter(([, v]) => v)
  return new Map(gm)
}

const main = async () => {
  const config = conf()
  if (!config) {
    return
  }

  const hook = await hookInput()
  if (!hook) {
    return
  }

  using time = measure(`${hook.hook_event_name} (session=${hook.session_id})`)

  const isSub = hook.hook_event_name === "SubagentStop"
  const stateKey = isSub
    ? `${hook.session_id}.${hook.agent_id}`
    : hook.session_id

  const userId = await gitUserName()
  await using state = await openState(stateKey)
  await using otel = provider(config)

  const opts = { offset: state.offset }
  const messages = await (isSub
    ? getSubagentMessages(hook.session_id, hook.agent_id, opts)
    : getSessionMessages(hook.session_id, opts))

  log({ level: "debug", msg: `messages: ${messages.length}` })

  const tracer = otel.provider.getTracer("langfuse-sdk")

  const traceName = `[${hook.session_id}] - ${hook.hook_event_name}`
  const attributes = {
    "user.id": userId,
    "session.id": hook.session_id,
    "langfuse.trace.name": traceName,
    "langfuse.trace.tags": ["claude-code"],
  }

  for (const [i, message] of messages.entries()) {
    const map = annotated(message)
    const { input = "", output = "", error = "" } = Object.fromEntries(map)
    if (!(input + output + error)) {
      continue
    }

    const startTime = time.jesus + i * 10
    using msg = defer(
      tracer.startSpan(`${traceName}: ${i}`, { startTime, attributes }),
    )

    if (input) {
      msg.span.setAttribute("langfuse.observation.input", input)
    }

    if (output) {
      msg.span.setAttribute("langfuse.observation.output", output)
    }

    if (error) {
      msg.span.setAttribute("langfuse.observation.output", error)
      msg.span.setAttribute("langfuse.observation.level", "ERROR")
    }
  }

  state.offset += messages.length
}

await main()
