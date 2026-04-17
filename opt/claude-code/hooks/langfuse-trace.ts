#!/usr/bin/env -S -- node

import type { BaseHookInput } from "@anthropic-ai/claude-agent-sdk"
import type {
  ContentBlock,
  Message,
  ToolResultBlockParam,
  ToolUseBlock,
} from "@anthropic-ai/sdk/resources/messages/messages.js"
import { LangfuseSpanProcessor } from "@langfuse/otel"
import {
  propagateAttributes,
  setLangfuseTracerProvider,
  startActiveObservation,
  startObservation,
} from "@langfuse/tracing"
import { NodeTracerProvider } from "@opentelemetry/sdk-trace-node"
import { createHash } from "node:crypto"
import { createReadStream } from "node:fs"
import { mkdir, readFile, rename, writeFile } from "node:fs/promises"
import { dirname, resolve } from "node:path"
import { env, exit, stdin } from "node:process"
import { text } from "node:stream/consumers"
import { fileURLToPath } from "node:url"

// ── Constants ────────────────────────────────────────

const MAX_CHARS = parseInt(env["CC_LANGFUSE_MAX_CHARS"] ?? "20000", 10)
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..")
const SESSIONS_DIR = resolve(ROOT, "var/sessions")

// ── Types ────────────────────────────────────────────

type Config = {
  publicKey: string
  secretKey: string
  host: string
}

type ReaderState = {
  offset: number
  buffer: string
  turnCount: number
}

type TranscriptLine = {
  type?: "user" | "assistant"
  message?: Partial<Message> & { role?: string }
  content?: Message["content"] | string
}

type TruncMeta = {
  truncated: boolean
  orig_len: number
  kept_len?: number
  sha256?: string
}

type ToolCall = {
  id: string
  name: string
  input: unknown
  output?: string | null
  output_meta?: TruncMeta
}

type Turn = {
  userMsg: TranscriptLine
  assistantMsgs: TranscriptLine[]
  toolResults: Map<string, unknown>
}

// ── Disposable helpers ───────────────────────────────

const disposable = <T extends { end(): void }>(obs: T) =>
  Object.assign(obs, { [Symbol.dispose]: () => obs.end() })

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

// ── Logging ──────────────────────────────────────────

const isDebug = env["CC_LANGFUSE_DEBUG"]?.toLowerCase() === "true"

const log = ({
  level,
  msg,
}: {
  level: "debug" | "info" | "error"
  msg: string
}) => {
  if (level === "debug" && !isDebug) return
  console.error(`[${level}] ${msg}`)
}

// ── Input ────────────────────────────────────────────

const readConfig = (): Config | null => {
  if (env["TRACE_TO_LANGFUSE"]?.toLowerCase() !== "true") return null

  const publicKey = env["CC_LANGFUSE_PUBLIC_KEY"] ?? env["LANGFUSE_PUBLIC_KEY"]
  const secretKey = env["CC_LANGFUSE_SECRET_KEY"] ?? env["LANGFUSE_SECRET_KEY"]
  if (!publicKey || !secretKey) return null

  const host =
    env["CC_LANGFUSE_BASE_URL"] ??
    env["LANGFUSE_BASE_URL"] ??
    "https://cloud.langfuse.com"

  return { publicKey, secretKey, host }
}

const readPayload = async () => {
  const data = await text(stdin)
  if (!data.trim()) return null
  return JSON.parse(data) as BaseHookInput & { hook_event_name?: string }
}

// ── State ────────────────────────────────────────────

const openState = async (sessionId: string) => {
  const path = resolve(SESSIONS_DIR, `${sessionId}.langfuse.json`)

  const state = await readFile(path, "utf-8")
    .then((data) => {
      const raw = JSON.parse(data)
      return {
        offset: Number(raw["offset"] ?? 0),
        buffer: String(raw["buffer"] ?? ""),
        turnCount: Number(raw["turn_count"] ?? 0),
      }
    })
    .catch(() => ({ offset: 0, buffer: "", turnCount: 0 }))

  return Object.assign(state, {
    async [Symbol.asyncDispose]() {
      const tmp = `${path}.tmp`
      const json = JSON.stringify(
        {
          offset: state.offset,
          buffer: state.buffer,
          turn_count: state.turnCount,
          updated: new Date().toISOString(),
        },
        null,
        2,
      )

      await mkdir(dirname(path), { recursive: true })
        .then(() => writeFile(tmp, json, "utf-8"))
        .then(() => rename(tmp, path))
        .catch((e) => log({ level: "error", msg: String(e) }))
    },
  })
}

// ── Message vocabulary ───────────────────────────────

const getContent = (msg: TranscriptLine) => msg.message?.content ?? msg.content

const getRole = (msg: TranscriptLine) => {
  const role = msg.type ?? msg.message?.role
  return role === "user" || role === "assistant" ? role : undefined
}

const contentBlocks = <T extends ContentBlock | ToolResultBlockParam>(
  content: (ContentBlock | ToolResultBlockParam)[] | string | undefined,
  blockType: string,
): T[] => {
  if (!Array.isArray(content)) return []
  return content.filter(
    (x): x is T => typeof x === "object" && x !== null && x.type === blockType,
  )
}

const isToolResult = (msg: TranscriptLine) =>
  getRole(msg) === "user" &&
  contentBlocks<ToolResultBlockParam>(getContent(msg), "tool_result").length > 0

const getModel = (msg: TranscriptLine) => msg.message?.model ?? "claude"

const getMessageId = (msg: TranscriptLine) => msg.message?.id ?? undefined

const extractText = (
  content: (ContentBlock | ToolResultBlockParam)[] | string | undefined,
): string => {
  if (typeof content === "string") return content
  if (!Array.isArray(content)) return ""

  return content
    .flatMap((block) => {
      if (typeof block === "string" && block) return [block]
      if (
        typeof block === "object" &&
        block !== null &&
        "type" in block &&
        block.type === "text" &&
        "text" in block &&
        typeof block.text === "string"
      )
        return [block.text]
      return []
    })
    .join("\n")
}

const truncate = (s: string, maxChars = MAX_CHARS): [string, TruncMeta] => {
  const origLen = s.length
  if (origLen <= maxChars) return [s, { truncated: false, orig_len: origLen }]
  const head = s.slice(0, maxChars)
  return [
    head,
    {
      truncated: true,
      orig_len: origLen,
      kept_len: head.length,
      sha256: createHash("sha256").update(s, "utf-8").digest("hex"),
    },
  ]
}

// ── Parse ────────────────────────────────────────────

const readNewMessages = async (
  path: string,
  state: ReaderState,
): Promise<[TranscriptLine[], ReaderState]> => {
  const chunk = await text(
    createReadStream(path, { start: state.offset, encoding: "utf-8" }),
  ).catch((e) => {
    log({ level: "error", msg: String(e) })
    return ""
  })
  if (!chunk) return [[], state]

  const combined = state.buffer + chunk
  const lines = combined.split("\n")

  const msgs = lines.slice(0, -1).flatMap((raw) => {
    const trimmed = raw.trim()
    if (!trimmed) return []
    try {
      return [JSON.parse(trimmed) as TranscriptLine]
    } catch {
      return []
    }
  })

  return [
    msgs,
    {
      ...state,
      offset: state.offset + Buffer.byteLength(chunk),
      buffer: lines.at(-1) ?? "",
    },
  ]
}

// ── Assemble ─────────────────────────────────────────

const assembleTurns = function* (
  messages: TranscriptLine[],
): IteratorObject<Turn> {
  let userMsg: TranscriptLine | null = null
  let assistants = new Map<string, TranscriptLine>()
  let toolResults = new Map<string, unknown>()

  for (const msg of messages) {
    if (isToolResult(msg)) {
      for (const tr of contentBlocks<ToolResultBlockParam>(
        getContent(msg),
        "tool_result",
      )) {
        if (tr.tool_use_id) toolResults.set(tr.tool_use_id, tr.content)
      }
      continue
    }

    const role = getRole(msg)

    if (role === "user") {
      if (userMsg !== null && assistants.size > 0) {
        yield {
          userMsg,
          assistantMsgs: assistants.values().toArray(),
          toolResults: new Map(toolResults),
        }
      }
      userMsg = msg
      assistants = new Map()
      toolResults = new Map()
      continue
    }

    if (role === "assistant" && userMsg !== null) {
      const mid = getMessageId(msg) ?? `noid:${assistants.size}`
      assistants.set(mid, msg)
      continue
    }
  }

  if (userMsg !== null && assistants.size > 0) {
    yield {
      userMsg,
      assistantMsgs: assistants.values().toArray(),
      toolResults: new Map(toolResults),
    }
  }

  return
}

// ── Emit ─────────────────────────────────────────────

const toolCalls = (assistantMsgs: TranscriptLine[]): ToolCall[] =>
  assistantMsgs.flatMap((am) =>
    contentBlocks<ToolUseBlock>(getContent(am), "tool_use").map((tu) => ({
      id: tu.id,
      name: tu.name,
      input: tu.input,
    })),
  )

const emitTurn = ({
  sessionId,
  turnNum,
  turn,
  transcriptPath,
}: {
  sessionId: string
  turnNum: number
  turn: Turn
  transcriptPath: string
}) => {
  const [userText, userMeta] = truncate(extractText(getContent(turn.userMsg)))
  const lastAssistant = turn.assistantMsgs.at(-1) ?? turn.userMsg
  const [assistantText, assistantMeta] = truncate(
    extractText(getContent(lastAssistant)),
  )
  const model = getModel(turn.assistantMsgs[0] ?? lastAssistant)
  const calls = toolCalls(turn.assistantMsgs)

  for (const c of calls) {
    const raw = turn.toolResults.get(c.id)
    if (raw !== undefined) {
      const outStr = typeof raw === "string" ? raw : JSON.stringify(raw)
      const [outTrunc, outMeta] = truncate(outStr)
      c.output = outTrunc
      c.output_meta = outMeta
    } else {
      c.output = null
    }
  }

  const traceName = `Claude Code - Turn ${turnNum}`

  propagateAttributes({ sessionId, traceName, tags: ["claude-code"] }, () =>
    startActiveObservation(traceName, (trace) => {
      trace.update({
        input: { role: "user", content: userText },
        metadata: {
          source: "claude-code",
          session_id: sessionId,
          turn_number: turnNum,
          transcript_path: transcriptPath,
          user_text: userMeta,
        },
      })

      {
        using _ = disposable(
          startObservation(
            "Claude Response",
            {
              input: { role: "user", content: userText },
              output: { role: "assistant", content: assistantText },
              model,
              metadata: {
                assistant_text: assistantMeta,
                tool_count: calls.length,
              },
            },
            { asType: "generation" },
          ),
        )
      }

      for (const c of calls) {
        const [inObj, inMeta] =
          typeof c.input === "string" ? truncate(c.input) : [c.input, null]

        using toolObs = disposable(
          startObservation(
            `Tool: ${c.name}`,
            {
              input: inObj,
              metadata: {
                tool_name: c.name,
                tool_id: c.id,
                input_meta: inMeta,
                output_meta: c.output_meta,
              },
            },
            { asType: "tool" },
          ),
        )
        toolObs.update({ output: c.output })
      }

      for (const c of calls) {
        if (c.name === "ExitPlanMode" && c.input) {
          const planStr =
            typeof c.input === "string" ? c.input : JSON.stringify(c.input)
          const [planTrunc, planMeta] = truncate(planStr)
          using _ = disposable(
            startObservation("Plan", {
              output: planTrunc,
              metadata: { plan_meta: planMeta },
            }),
          )
        }
      }

      trace.update({ output: { role: "assistant", content: assistantText } })
    }),
  )
}

// ── Provider lifecycle ───────────────────────────────

const createProvider = (config: Config) => {
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

// ── Main ─────────────────────────────────────────────

const main = async () => {
  const config = readConfig()
  if (!config) return 0

  const payload = await readPayload()
  if (!payload) return 0

  const event = (payload.hook_event_name ?? "unknown").padEnd(
    "PostToolUseFailure".length,
  )
  using _ = timed(`${event} (session=${payload.session_id})`)
  await using __ = createProvider(config)

  await using state = await openState(payload.session_id)

  const [msgs, nextState] = await readNewMessages(
    payload.transcript_path,
    state,
  )
  Object.assign(state, nextState)

  if (!msgs.length) return 0

  const turns = assembleTurns(msgs).toArray()
  if (!turns.length) return 0

  for (const [i, turn] of turns.entries()) {
    try {
      emitTurn({
        sessionId: payload.session_id,
        turnNum: state.turnCount + i + 1,
        turn,
        transcriptPath: payload.transcript_path,
      })
    } catch (e) {
      log({ level: "error", msg: String(e) })
    }
  }

  state.turnCount += turns.length

  return 0
}

exit(await main())
