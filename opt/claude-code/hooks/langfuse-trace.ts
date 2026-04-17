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

type SessionState = AsyncDisposable & { offset: number }

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

const openState = async (sessionId: string): Promise<SessionState> => {
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

const contents = function* (messages: SessionMessage[]): IteratorObject<Block> {
  for (const message of messages) {
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
  }

  return
}

type Extracted =
  | { error: string }
  | { content: string }
  | { name: string; input: unknown }
  | { output: unknown }

const extract = (block: Block): Extracted | undefined => {
  if (typeof block === "string") {
    return { content: block }
  }

  switch (block.type) {
    case "compaction":
      return { content: block.content ?? "" }
    case "text":
      return { content: block.text }
    case "thinking":
      return { content: block.thinking }

    case "mcp_tool_use":
    case "server_tool_use":
    case "tool_use":
      return { name: block.name, input: block.input }

    case "bash_code_execution_tool_result":
      switch (block.content.type) {
        case "bash_code_execution_tool_result_error":
          return { error: block.content.error_code }
        case "bash_code_execution_result":
          return {
            output: {
              return_code: block.content.return_code,
              stderr: block.content.stderr,
              stdout: block.content.stdout,
            },
          }
        default:
          fail(block.content satisfies never)
      }

    case "code_execution_tool_result":
    case "mcp_tool_result":
    case "search_result":
    case "text_editor_code_execution_tool_result":
    case "tool_result":
    case "tool_search_tool_result":
    case "web_fetch_tool_result":
    case "web_search_tool_result":
      return { output: block.content }
    case "document":
    case "image":
    case "redacted_thinking":
    case "container_upload":
      return undefined
    default:
      fail(block satisfies never)
  }

  return
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
  await using __ = provider(config)

  const opts = { offset: state?.offset }
  const messages = await (isSub
    ? getSubagentMessages(hook.session_id, hook.agent_id, opts)
    : getSessionMessages(hook.session_id, opts))

  const texts = contents(messages).flatMap(extractText).toArray()

  if (state) {
    state.offset += messages.length
  }
}

await main()
