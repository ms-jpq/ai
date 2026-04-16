#!/usr/bin/env -S -- node

import type {
  ContentBlock,
  Message,
  TextBlock,
  ToolResultBlockParam,
  ToolUseBlock,
} from "@anthropic-ai/sdk/resources/messages/messages.js";
import type { BaseHookInput } from "@anthropic-ai/claude-agent-sdk";
import { LangfuseSpanProcessor } from "@langfuse/otel";
import {
  propagateAttributes,
  setLangfuseTracerProvider,
  startObservation,
} from "@langfuse/tracing";
import { NodeTracerProvider } from "@opentelemetry/sdk-trace-node";
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { text } from "node:stream/consumers";
import { open } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { env, exit, stdin } from "node:process";
import { fileURLToPath } from "node:url";

// ── Constants ────────────────────────────────────────

const MAX_CHARS = parseInt(env["CC_LANGFUSE_MAX_CHARS"] ?? "20000", 10);
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const SESSIONS_DIR = resolve(ROOT, "var/sessions");

// ── Types ────────────────────────────────────────────

type TranscriptLine = {
  type?: "user" | "assistant";
  message?: Partial<Message> & { role?: string };
  content?: Message["content"] | string;
};

type TruncMeta = {
  truncated: boolean;
  orig_len: number;
  kept_len?: number;
  sha256?: string;
};

type ToolCall = {
  id: string;
  name: string;
  input: unknown;
  output?: string | null;
  output_meta?: TruncMeta;
};

type Config = {
  publicKey: string;
  secretKey: string;
  host: string;
};

type ReaderState = {
  offset: number;
  buffer: string;
  turnCount: number;
};

type Turn = {
  userMsg: TranscriptLine;
  assistantMsgs: TranscriptLine[];
  toolResults: Map<string, unknown>;
};

// ── Disposable observation ───────────────────────────

const disposable = <T extends { end(): void }>(obs: T) =>
  Object.assign(obs, { [Symbol.dispose]: () => obs.end() });

// ── Logging ──────────────────────────────────────────

const isDebug = env["CC_LANGFUSE_DEBUG"]?.toLowerCase() === "true";

const log = ({
  level,
  msg,
}: {
  level: "debug" | "info" | "error";
  msg: string;
}) => {
  if (level === "debug" && !isDebug) return;
  console.error(`[${level}] ${msg}`);
};

// ── Input ────────────────────────────────────────────

const readConfig = (): Config | null => {
  if (env["TRACE_TO_LANGFUSE"]?.toLowerCase() !== "true") return null;

  const publicKey = env["CC_LANGFUSE_PUBLIC_KEY"] ?? env["LANGFUSE_PUBLIC_KEY"];
  const secretKey = env["CC_LANGFUSE_SECRET_KEY"] ?? env["LANGFUSE_SECRET_KEY"];
  if (!publicKey || !secretKey) return null;

  const host =
    env["CC_LANGFUSE_BASE_URL"] ??
    env["LANGFUSE_BASE_URL"] ??
    "https://cloud.langfuse.com";

  return { publicKey, secretKey, host };
};

const readPayload = async () => {
  const data = await text(stdin);
  if (!data.trim()) return null;
  return JSON.parse(data) as BaseHookInput;
};

// ── State ────────────────────────────────────────────

const statePath = (sessionId: string) =>
  resolve(SESSIONS_DIR, `${sessionId}.langfuse.json`);

const loadState = (sessionId: string): ReaderState => {
  const p = statePath(sessionId);
  try {
    if (existsSync(p)) {
      const raw = JSON.parse(readFileSync(p, "utf-8"));
      return {
        offset: Number(raw["offset"] ?? 0),
        buffer: String(raw["buffer"] ?? ""),
        turnCount: Number(raw["turn_count"] ?? 0),
      };
    }
  } catch (e) {
    log({ level: "error", msg: String(e) });
  }
  return { offset: 0, buffer: "", turnCount: 0 };
};

const saveState = (sessionId: string, state: ReaderState) => {
  try {
    const p = statePath(sessionId);
    mkdirSync(dirname(p), { recursive: true });
    const tmp = `${p}.tmp`;
    writeFileSync(
      tmp,
      JSON.stringify(
        {
          offset: state.offset,
          buffer: state.buffer,
          turn_count: state.turnCount,
          updated: new Date().toISOString(),
        },
        null,
        2,
      ),
      "utf-8",
    );
    renameSync(tmp, p);
  } catch (e) {
    log({ level: "error", msg: String(e) });
  }
};

// ── Message vocabulary ───────────────────────────────

const getContent = (msg: TranscriptLine) =>
  msg.message?.content ?? msg.content;

const getRole = (msg: TranscriptLine) => {
  const role = msg.type ?? msg.message?.role;
  return role === "user" || role === "assistant" ? role : undefined;
};

const contentBlocks = <T extends ContentBlock | ToolResultBlockParam>(
  content: unknown,
  blockType: string,
): T[] => {
  if (!Array.isArray(content)) return [];
  return content.filter(
    (x): x is T => typeof x === "object" && x !== null && x.type === blockType,
  );
};

const isToolResult = (msg: TranscriptLine) =>
  getRole(msg) === "user" &&
  contentBlocks<ToolResultBlockParam>(getContent(msg), "tool_result").length > 0;

const getModel = (msg: TranscriptLine) =>
  msg.message?.model || "claude";

const getMessageId = (msg: TranscriptLine) =>
  msg.message?.id || undefined;

const extractText = (content: unknown): string => {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";

  const parts: string[] = [];
  for (const block of content) {
    if (typeof block === "string" && block) {
      parts.push(block);
    } else if (
      typeof block === "object" &&
      block !== null &&
      "type" in block &&
      block.type === "text" &&
      "text" in block &&
      typeof block.text === "string"
    ) {
      parts.push(block.text);
    }
  }
  return parts.join("\n");
};

const truncate = (s: string, maxChars = MAX_CHARS): [string, TruncMeta] => {
  const origLen = s.length;
  if (origLen <= maxChars) return [s, { truncated: false, orig_len: origLen }];
  const head = s.slice(0, maxChars);
  return [
    head,
    {
      truncated: true,
      orig_len: origLen,
      kept_len: head.length,
      sha256: createHash("sha256").update(s, "utf-8").digest("hex"),
    },
  ];
};

// ── Parse ────────────────────────────────────────────

const readNewMessages = async (
  path: string,
  state: ReaderState,
): Promise<[TranscriptLine[], ReaderState]> => {
  let chunk: Buffer;
  let newOffset: number;
  try {
    await using fh = await open(path, "r");
    const stat = await fh.stat();
    const size = stat.size - state.offset;
    if (size <= 0) return [[], state];
    chunk = Buffer.alloc(size);
    const { bytesRead } = await fh.read(chunk, 0, size, state.offset);
    newOffset = state.offset + bytesRead;
  } catch (e) {
    log({ level: "error", msg: String(e) });
    return [[], state];
  }

  const combined = state.buffer + chunk.toString("utf-8");
  const lines = combined.split("\n");

  const msgs: TranscriptLine[] = [];
  for (const raw of lines.slice(0, -1)) {
    const line = raw.trim();
    if (!line) continue;
    try {
      msgs.push(JSON.parse(line));
    } catch {
      // skip malformed lines
    }
  }

  return [
    msgs,
    { ...state, offset: newOffset, buffer: lines[lines.length - 1] ?? "" },
  ];
};

// ── Assemble ─────────────────────────────────────────

function* assembleTurns(messages: TranscriptLine[]): Generator<Turn> {
  let userMsg: TranscriptLine | null = null;
  let assistants = new Map<string, TranscriptLine>();
  let toolResults = new Map<string, unknown>();

  for (const msg of messages) {
    if (isToolResult(msg)) {
      for (const tr of contentBlocks<ToolResultBlockParam>(
        getContent(msg),
        "tool_result",
      )) {
        if (tr.tool_use_id) toolResults.set(tr.tool_use_id, tr.content);
      }
      continue;
    }

    const role = getRole(msg);

    if (role === "user") {
      if (userMsg !== null && assistants.size > 0) {
        yield {
          userMsg,
          assistantMsgs: [...assistants.values()],
          toolResults: new Map(toolResults),
        };
      }
      userMsg = msg;
      assistants = new Map();
      toolResults = new Map();
      continue;
    }

    if (role === "assistant" && userMsg !== null) {
      const mid = getMessageId(msg) ?? `noid:${assistants.size}`;
      assistants.set(mid, msg);
      continue;
    }
  }

  if (userMsg !== null && assistants.size > 0) {
    yield {
      userMsg,
      assistantMsgs: [...assistants.values()],
      toolResults: new Map(toolResults),
    };
  }
}

// ── Emit ─────────────────────────────────────────────

const toolCalls = (assistantMsgs: TranscriptLine[]) => {
  const calls: ToolCall[] = [];
  for (const am of assistantMsgs) {
    for (const tu of contentBlocks<ToolUseBlock>(
      getContent(am),
      "tool_use",
    )) {
      calls.push({
        id: tu.id,
        name: tu.name,
        input: tu.input,
      });
    }
  }
  return calls;
};

const emitTurn = ({
  sessionId,
  turnNum,
  turn,
  transcriptPath,
}: {
  sessionId: string;
  turnNum: number;
  turn: Turn;
  transcriptPath: string;
}) => {
  const [userText, userMeta] = truncate(
    extractText(getContent(turn.userMsg)),
  );
  const lastAssistant = turn.assistantMsgs.at(-1) ?? turn.userMsg;
  const [assistantText, assistantMeta] = truncate(
    extractText(getContent(lastAssistant)),
  );
  const model = getModel(turn.assistantMsgs[0] ?? lastAssistant);
  const calls = toolCalls(turn.assistantMsgs);

  for (const c of calls) {
    const raw = turn.toolResults.get(c.id);
    if (raw !== undefined) {
      const outStr = typeof raw === "string" ? raw : JSON.stringify(raw);
      const [outTrunc, outMeta] = truncate(outStr);
      c.output = outTrunc;
      c.output_meta = outMeta;
    } else {
      c.output = null;
    }
  }

  const traceName = `Claude Code - Turn ${turnNum}`;

  propagateAttributes({ sessionId, traceName, tags: ["claude-code"] }, () => {
    using trace = disposable(startObservation(traceName, {
      input: { role: "user", content: userText },
      metadata: {
        source: "claude-code",
        session_id: sessionId,
        turn_number: turnNum,
        transcript_path: transcriptPath,
        user_text: userMeta,
      },
    }));

    {
      using _ = disposable(startObservation(
        "Claude Response",
        {
          input: { role: "user", content: userText },
          output: { role: "assistant", content: assistantText },
          model,
          metadata: { assistant_text: assistantMeta, tool_count: calls.length },
        },
        { asType: "generation" },
      ));
    }

    for (const c of calls) {
      let inObj: unknown = c.input;
      let inMeta: TruncMeta | null = null;
      if (typeof inObj === "string") [inObj, inMeta] = truncate(inObj);

      using toolObs = disposable(startObservation(
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
      ));
      toolObs.update({ output: c.output });
    }

    for (const c of calls) {
      if (c.name === "ExitPlanMode" && c.input) {
        const planStr =
          typeof c.input === "string" ? c.input : JSON.stringify(c.input);
        const [planTrunc, planMeta] = truncate(planStr);
        using _ = disposable(startObservation("Plan", {
          output: planTrunc,
          metadata: { plan_meta: planMeta },
        }));
      }
    }

    trace.update({ output: { role: "assistant", content: assistantText } });
  });
};

// ── Provider lifecycle ───────────────────────────────

const createProvider = (config: Config) => {
  const processor = new LangfuseSpanProcessor({
    publicKey: config.publicKey,
    secretKey: config.secretKey,
    baseUrl: config.host,
    timeout: 10,
    exportMode: "immediate",
  });

  const provider = new NodeTracerProvider({ spanProcessors: [processor] });
  setLangfuseTracerProvider(provider);

  return {
    provider,
    async [Symbol.asyncDispose]() {
      await provider.shutdown();
      setLangfuseTracerProvider(null);
    },
  };
};

// ── Main ─────────────────────────────────────────────

const main = async () => {
  const config = readConfig();
  if (!config) return 0;

  const payload = await readPayload();
  if (!payload) return 0;

  const start = performance.now();
  log({ level: "debug", msg: `hook started (session=${payload.session_id})` });

  {
    await using _ = createProvider(config);

    let state = loadState(payload.session_id);
    const [msgs, nextState] = await readNewMessages(
      payload.transcript_path,
      state,
    );
    state = nextState;

    if (!msgs.length) {
      saveState(payload.session_id, state);
      return 0;
    }

    const turns = [...assembleTurns(msgs)];
    if (!turns.length) {
      saveState(payload.session_id, state);
      return 0;
    }

    let emitted = 0;
    for (const turn of turns) {
      emitted += 1;
      try {
        emitTurn({
          sessionId: payload.session_id,
          turnNum: state.turnCount + emitted,
          turn,
          transcriptPath: payload.transcript_path,
        });
      } catch (e) {
        log({ level: "error", msg: String(e) });
      }
    }

    state = { ...state, turnCount: state.turnCount + emitted };
    saveState(payload.session_id, state);

    const dur = ((performance.now() - start) / 1000).toFixed(2);
    log({
      level: "info",
      msg: `Processed ${emitted} turns in ${dur}s (session=${payload.session_id})`,
    });
  }

  return 0;
};

exit(await main());
