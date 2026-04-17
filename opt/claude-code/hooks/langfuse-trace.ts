#!/usr/bin/env -S -- node

import type {
  HookInput,
  SDKMessage,
  SessionMessage,
} from "@anthropic-ai/claude-agent-sdk"
import {
  getSessionMessages,
  getSubagentMessages,
} from "@anthropic-ai/claude-agent-sdk"
import type { BetaContentBlock } from "@anthropic-ai/sdk/resources/beta/messages/messages.js"
import type { ContentBlockParam } from "@anthropic-ai/sdk/resources/messages/messages.js"
import { LangfuseSpanProcessor } from "@langfuse/otel"
import { setLangfuseTracerProvider } from "@langfuse/tracing"
import { NodeTracerProvider } from "@opentelemetry/sdk-trace-node"
import { fail, ok } from "node:assert/strict"
import { mkdir, readFile, rename, writeFile } from "node:fs/promises"
import { dirname, resolve } from "node:path"
import { env, stdin } from "node:process"
import { text } from "node:stream/consumers"
import { fileURLToPath } from "node:url"

type Conf = { publicKey: string; secretKey: string; host: string }

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..,", "..")
const SESSIONS_DIR = resolve(ROOT, "var", "sessions")

const log = ({
  level,
  msg,
}: {
  level: "debug" | "info" | "error"
  msg: string
}) => console.error(`[${level}] ${msg}`)

const timed = (label: string) => {
  const start = performance.now()
  log({ level: "debug", msg: `${label} started` })

  return {
    [Symbol.dispose]() {
      const dur = ((performance.now() - start) / 1000).toFixed(2)
      log({ level: "info", msg: `${label} completed in ${dur}s` })
    },
  }
}

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
  sessionId: string,
): Promise<AsyncDisposable & { offset: number }> => {
  const path = resolve(SESSIONS_DIR, `${sessionId}.langfuse.json`)
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
  const processor = new LangfuseSpanProcessor({
    publicKey: config.publicKey,
    secretKey: config.secretKey,
    baseUrl: config.host,
    timeout: 10,
    exportMode: "immediate",
  })
  const provider = new NodeTracerProvider({ spanProcessors: [processor] })

  provider.register()
  setLangfuseTracerProvider(provider)

  return {
    provider,
    async [Symbol.asyncDispose]() {
      await provider.shutdown()
    },
  }
}

type Block = string | BetaContentBlock | ContentBlockParam

const contents = function* (message: SessionMessage): IteratorObject<Block> {
  const msg = message.message as SDKMessage
  switch (msg.type) {
    case "assistant":
      yield* msg.message.content
      break
    case "user":
      if (typeof msg.message.content === "string") {
        yield msg.message.content
      }
      yield* msg.message.content
      break
    default:
      break
  }

  return
}

type Extracted =
  | { type: "error"; error: unknown }
  | { type: "content"; content: string }
  | { type: "tool_use"; name: string; input: unknown }
  | { type: "output"; output: unknown }

const extract = (block: Block): Extracted | undefined => {
  if (typeof block === "string") {
    return { type: "content", content: block }
  }

  switch (block.type) {
    case "compaction":
      return { type: "content", content: block.content ?? "" }
    case "text":
      return { type: "content", content: block.text }
    case "thinking":
      return { type: "content", content: block.thinking }

    case "mcp_tool_use":
    case "server_tool_use":
    case "tool_use":
      return { type: "tool_use", name: block.name, input: block.input }

    case "code_execution_tool_result":
    case "bash_code_execution_tool_result":
      switch (block.content.type) {
        case "bash_code_execution_tool_result_error":
        case "code_execution_tool_result_error":
          return { type: "error", error: block.content.error_code }
        case "encrypted_code_execution_result":
          return {
            type: "output",
            output: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
            },
          }
        case "bash_code_execution_result":
        case "code_execution_result":
          return {
            type: "output",
            output: {
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
        return { type: "error", error: block.content }
      }
      return { type: "output", output: block.content }

    case "search_result":
      return {
        type: "output",
        output: {
          source: block.source,
          title: block.title,
          content: block.content,
        },
      }

    case "text_editor_code_execution_tool_result":
      switch (block.content.type) {
        case "text_editor_code_execution_tool_result_error":
          return { type: "error", error: block.content.error_code }
        case "text_editor_code_execution_view_result":
          return { type: "content", content: block.content.content }
        case "text_editor_code_execution_create_result":
          return {
            type: "output",
            output: { is_file_update: block.content.is_file_update },
          }
        case "text_editor_code_execution_str_replace_result":
          return {
            type: "output",
            output: {
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
          return { type: "error", error: block.content.error_code }
        case "tool_search_tool_search_result":
          return { type: "output", output: block.content.tool_references }
        default:
          fail(block.content satisfies never)
      }

    case "web_search_tool_result":
      if (Array.isArray(block.content)) {
        return {
          type: "output",
          output: block.content.map((r) => ({ title: r.title, url: r.url })),
        }
      }
      return { type: "error", error: block.content.error_code }

    case "web_fetch_tool_result":
      switch (block.content.type) {
        case "web_fetch_tool_result_error":
          return { type: "error", error: block.content.error_code }
        case "web_fetch_result":
          return {
            type: "output",
            output: {
              url: block.content.url,
              retrieved_at: block.content.retrieved_at,
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "document":
    case "image":
    case "redacted_thinking":
    case "container_upload":
      return undefined
    default:
      fail(block satisfies never)
  }
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

  using _ = timed(`${hook.hook_event_name} (session=${hook.session_id})`)

  const isSub = hook.hook_event_name === "SubagentStop"
  await using state = isSub ? undefined : await openState(hook.session_id)
  await using otel = provider(config)

  const opts = { offset: state?.offset }
  const messages = await (isSub
    ? getSubagentMessages(hook.session_id, hook.agent_id, opts)
    : getSessionMessages(hook.session_id, opts))

  const tracer = otel.provider.getTracer("claude-code")

  for (const message of messages) {
    const msg = message.message as SDKMessage
    tracer.startActiveSpan(
      msg.type,
      { attributes: { "session.id": hook.session_id } },
      (span) => {
        try {
          for (const block of contents(message)) {
            const extracted = extract(block)
            if (!extracted) {
              continue
            }

            switch (extracted.type) {
              case "content":
                span.addEvent("content", { value: extracted.content })
                break
              case "tool_use":
                span.addEvent(`tool:${extracted.name}`, {
                  input: JSON.stringify(extracted.input),
                })
                break
              case "output":
                span.addEvent("output", {
                  value: JSON.stringify(extracted.output),
                })
                break
              case "error":
                span.addEvent("error", {
                  value: JSON.stringify(extracted.error),
                })
                break
              default:
                fail(extracted satisfies never)
            }
          }
        } finally {
          span.end()
        }
      },
    )
  }

  if (state) {
    state.offset += messages.length
  }
}

await main()
