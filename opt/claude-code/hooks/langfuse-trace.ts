#!/usr/bin/env -S -- node

import type { HookInput } from "@anthropic-ai/claude-agent-sdk"
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

type SessionState = {
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
}

type ResolvedToolCall = ToolCall & {
  output?: string
  output_meta?: TruncMeta
}

type Turn = {
  userMsg: TranscriptLine
  assistantMsgs: TranscriptLine[]
  toolResults: Map<string, unknown>
}

type TurnData = {
  userText: string
  userMeta: TruncMeta
  assistantText: string
  assistantMeta: TruncMeta
  model: string
  tools: ResolvedToolCall[]
}

type TurnEvent = {
  kind: "turn"
  sessionId: string
  transcriptPath: string
  turnNum: number
  data: TurnData
  lastAssistantMessage?: string
  error?: string
  errorDetails?: string
}

type SubagentEvent = {
  kind: "subagent"
  sessionId: string
  agentId: string
  agentType: string
  agentTranscriptPath: string
  turns: TurnData[]
  inputText: string
  inputMeta: TruncMeta
  outputText: string
  outputMeta: TruncMeta
}

type PipeEvent = TurnEvent | SubagentEvent

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

const readConfig = (): Config | undefined => {
  if (env["TRACE_TO_LANGFUSE"]?.toLowerCase() !== "true") return undefined

  const publicKey = env["CC_LANGFUSE_PUBLIC_KEY"] ?? env["LANGFUSE_PUBLIC_KEY"]
  const secretKey = env["CC_LANGFUSE_SECRET_KEY"] ?? env["LANGFUSE_SECRET_KEY"]
  if (!publicKey || !secretKey) return undefined

  const host =
    env["CC_LANGFUSE_BASE_URL"] ??
    env["LANGFUSE_BASE_URL"] ??
    "https://cloud.langfuse.com"

  return { publicKey, secretKey, host }
}

const readPayload = async () => {
  const data = await text(stdin)
  if (!data.trim()) return null
  return JSON.parse(data) as HookInput
}

// ── State ────────────────────────────────────────────

const openState = async (sessionId: string) => {
  const path = resolve(SESSIONS_DIR, `${sessionId}.langfuse.json`)

  const state: SessionState = await readFile(path, "utf-8")
    .then((data) => ({
      turnCount: Number(JSON.parse(data)["turn_count"] ?? 0),
    }))
    .catch(() => ({ turnCount: 0 }))

  return Object.assign(state, {
    async [Symbol.asyncDispose]() {
      const tmp = `${path}.tmp`
      const json = JSON.stringify(
        { turn_count: state.turnCount, updated: new Date().toISOString() },
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

const readTranscript = async (path: string): Promise<TranscriptLine[]> => {
  const content = await readFile(path, "utf-8").catch((e) => {
    log({ level: "error", msg: String(e) })
    return ""
  })
  if (!content) return []

  return content.split("\n").flatMap((raw) => {
    const trimmed = raw.trim()
    if (!trimmed) return []
    try {
      return [JSON.parse(trimmed) as TranscriptLine]
    } catch {
      return []
    }
  })
}

// ── Assemble ─────────────────────────────────────────

const assembleTurns = function* (
  messages: TranscriptLine[],
): IteratorObject<Turn> {
  let userMsg: TranscriptLine | null = null
  const assistants = new Map<string, TranscriptLine>()
  const toolResults = new Map<string, unknown>()

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
      assistants.clear()
      toolResults.clear()
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

// ── Resolve ─────────────────────────────────────────

const toolCalls = (assistantMsgs: TranscriptLine[]): ToolCall[] =>
  assistantMsgs.flatMap((am) =>
    contentBlocks<ToolUseBlock>(getContent(am), "tool_use").map((tu) => ({
      id: tu.id,
      name: tu.name,
      input: tu.input,
    })),
  )

const resolveToolCalls = (turn: Turn): ResolvedToolCall[] =>
  toolCalls(turn.assistantMsgs).map((c) => {
    const raw = turn.toolResults.get(c.id)
    if (raw === undefined) return c
    const outStr = typeof raw === "string" ? raw : JSON.stringify(raw)
    const [output, output_meta] = truncate(outStr)
    return { ...c, output, output_meta }
  })

const resolveTurnData = (turn: Turn): TurnData => {
  const [userText, userMeta] = truncate(extractText(getContent(turn.userMsg)))
  const lastAssistant = turn.assistantMsgs.at(-1)!
  const [assistantText, assistantMeta] = truncate(
    extractText(getContent(lastAssistant)),
  )
  const model = getModel(turn.assistantMsgs[0]!)
  const tools = resolveToolCalls(turn)
  return { userText, userMeta, assistantText, assistantMeta, model, tools }
}

// ── Pipeline ────────────────────────────────────────

const toEvents = function* (
  lines: TranscriptLine[],
  payload: HookInput,
  skipTurns: number,
): IteratorObject<PipeEvent> {
  const turns = assembleTurns(lines).map(resolveTurnData).toArray()

  if (payload.hook_event_name === "SubagentStop") {
    const first = turns[0]
    if (!first) return
    const last = turns.at(-1)!
    const lastText = payload.last_assistant_message ?? last.assistantText
    const [outputText, outputMeta] = truncate(lastText)
    yield {
      kind: "subagent",
      sessionId: payload.session_id,
      agentId: payload.agent_id,
      agentType: payload.agent_type,
      agentTranscriptPath: payload.agent_transcript_path,
      turns,
      inputText: first.userText,
      inputMeta: first.userMeta,
      outputText,
      outputMeta,
    }
    return
  }

  const isStop =
    payload.hook_event_name === "Stop" ||
    payload.hook_event_name === "StopFailure"
  const emitUpTo = isStop ? turns.length : Math.max(0, turns.length - 1)

  for (let i = skipTurns; i < emitUpTo; i++) {
    const isLast = i === turns.length - 1
    yield {
      kind: "turn",
      sessionId: payload.session_id,
      transcriptPath: payload.transcript_path,
      turnNum: i + 1,
      data: turns[i]!,
      lastAssistantMessage:
        isStop && isLast ? payload.last_assistant_message : undefined,
      error:
        payload.hook_event_name === "StopFailure" && isLast
          ? payload.error
          : undefined,
      errorDetails:
        payload.hook_event_name === "StopFailure" && isLast
          ? payload.error_details
          : undefined,
    }
  }

  return
}

// ── Emit ─────────────────────────────────────────────

const emitTurnObservations = ({
  generationName,
  userText,
  assistantText,
  assistantMeta,
  model,
  tools,
}: { generationName: string } & TurnData) => {
  {
    using _ = disposable(
      startObservation(
        generationName,
        {
          input: { role: "user", content: userText },
          output: { role: "assistant", content: assistantText },
          model,
          metadata: {
            assistant_text: assistantMeta,
            tool_count: tools.length,
          },
        },
        { asType: "generation" },
      ),
    )
  }

  for (const c of tools) {
    const [inObj, inMeta] =
      typeof c.input === "string" ? truncate(c.input) : [c.input, undefined]

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
}

const emit = (event: PipeEvent): void => {
  switch (event.kind) {
    case "turn": {
      const { data, turnNum, sessionId, transcriptPath, error, errorDetails } =
        event
      const outputText = data.assistantText || event.lastAssistantMessage || ""
      const traceName = `Claude Code - Turn ${turnNum}`

      propagateAttributes({ sessionId, traceName, tags: ["claude-code"] }, () =>
        startActiveObservation(traceName, (trace) => {
          trace.update({
            input: { role: "user", content: data.userText },
            metadata: {
              source: "claude-code",
              session_id: sessionId,
              turn_number: turnNum,
              transcript_path: transcriptPath,
              user_text: data.userMeta,
              ...(error ? { error, error_details: errorDetails } : {}),
            },
          })

          emitTurnObservations({
            generationName: "Claude Response",
            ...data,
          })

          trace.update({
            output: { role: "assistant", content: outputText },
            ...(error ? { level: "ERROR" } : {}),
          })
        }),
      )
      break
    }

    case "subagent": {
      const traceName = `Claude Code - Subagent: ${event.agentType}`
      const tags = ["claude-code", "subagent", event.agentType]

      propagateAttributes({ sessionId: event.sessionId, traceName, tags }, () =>
        startActiveObservation(traceName, (trace) => {
          trace.update({
            input: { role: "user", content: event.inputText },
            metadata: {
              source: "claude-code",
              session_id: event.sessionId,
              agent_id: event.agentId,
              agent_type: event.agentType,
              agent_transcript_path: event.agentTranscriptPath,
              input_meta: event.inputMeta,
              output_meta: event.outputMeta,
              turn_count: event.turns.length,
            },
          })

          for (const [i, turn] of event.turns.entries()) {
            emitTurnObservations({
              generationName: `Turn ${i + 1}`,
              ...turn,
            })
          }

          trace.update({
            output: { role: "assistant", content: event.outputText },
          })
        }),
      )
      break
    }
  }
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

  using _ = timed(`${payload.hook_event_name} (session=${payload.session_id})`)
  await using __ = createProvider(config)

  // Stage 2
  const transcriptPath =
    payload.hook_event_name === "SubagentStop"
      ? payload.agent_transcript_path
      : payload.transcript_path
  const lines = await readTranscript(transcriptPath)

  // State
  const isSubagent = payload.hook_event_name === "SubagentStop"
  await using state = isSubagent
    ? undefined
    : await openState(payload.session_id)
  const skipTurns = state?.turnCount ?? 0

  // Stage 3+4
  const events = toEvents(lines, payload, skipTurns)

  // Stage 5
  let emitted = 0
  for (const event of events) {
    try {
      emit(event)
      emitted++
    } catch (e) {
      log({ level: "error", msg: String(e) })
    }
  }

  if (state) state.turnCount = skipTurns + emitted

  return 0
}

exit(await main())
