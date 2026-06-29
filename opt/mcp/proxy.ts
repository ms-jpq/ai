#!/usr/bin/env -S -- node

import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js"
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js"
import type { JSONRPCErrorResponse } from "@modelcontextprotocol/sdk/types.js"
import { randomUUID } from "node:crypto"
import { once } from "node:events"
import { createServer, type ServerResponse } from "node:http"
import { EOL } from "node:os"
import { exit, stderr } from "node:process"
import { parseArgs } from "node:util"

type Session = { http: StreamableHTTPServerTransport; timer: ReturnType<typeof setTimeout> } & (
  | { phase: "idle" }
  | {
      phase: "spawning"
      spawning: Promise<StdioClientTransport>
    }
  | {
      phase: "live"
      stdio: StdioClientTransport
    }
)

const {
  positionals: [serverCmd, ...serverArgs],
  values,
} = parseArgs({
  options: {
    port: { type: "string", short: "p", default: String(3000) },
    ttl: { type: "string", default: String(30000) },
  },
  allowPositionals: true,
})

const log = (msg: string) => stderr.write(`${import.meta.filename}: ${msg}${EOL}`)

if (!serverCmd) {
  log(`usage: [--port <n>] [--ttl <ms>] <command> [args...]`)
  exit(2)
}

const PORT = parseInt(values.port, 10)
const SESSION_TTL_MS = parseInt(values.ttl, 10)

const sessions = new Map<string, Session>()

const teardown = async (sid: string) => {
  const s = sessions.get(sid)
  if (!s) {
    return
  }

  clearTimeout(s.timer)
  sessions.delete(sid)

  const closes = function* (): Generator<Promise<void>> {
    if (s.phase === "spawning") {
      yield s.spawning.then((t) => t.close())
    }
    if (s.phase === "live") {
      yield s.stdio.close()
    }
    yield s.http.close()
  }

  await Promise.all(closes())
}

const ensure = async (sid: string): Promise<StdioClientTransport> => {
  const s = sessions.get(sid)
  if (!s) {
    throw new Error("Session not found")
  }

  switch (s.phase) {
    case "live": {
      clearTimeout(s.timer)
      sessions.set(sid, { ...s, timer: setTimeout(() => teardown(sid), SESSION_TTL_MS) })
      return s.stdio
    }
    case "spawning": {
      clearTimeout(s.timer)
      sessions.set(sid, { ...s, timer: setTimeout(() => teardown(sid), SESSION_TTL_MS) })
      return s.spawning
    }
    case "idle": {
      clearTimeout(s.timer)
      const timer = setTimeout(() => teardown(sid), SESSION_TTL_MS)

      const transport = new StdioClientTransport({ command: serverCmd, args: serverArgs })

      transport.onclose = transport.onerror = () => {
        const cur = sessions.get(sid)
        if (!cur) {
          return
        }
        cur.http.closeStandaloneSSEStream()
        if (cur.phase === "live") {
          sessions.set(sid, { phase: "idle", http: cur.http, timer: cur.timer })
        }
      }

      transport.onmessage = async (msg) => {
        try {
          const cur = sessions.get(sid)
          if (cur) {
            await cur.http.send(msg)
          }
        } catch (err) {
          log(`send: ${err}`)
        }
      }

      const spawning = (async () => {
        try {
          await transport.start()
          const cur = sessions.get(sid)
          if (cur && cur.phase === "spawning") {
            sessions.set(sid, { phase: "live", http: cur.http, timer: cur.timer, stdio: transport })
          }
          return transport
        } catch (err) {
          const cur = sessions.get(sid)
          if (cur && cur.phase === "spawning") {
            sessions.set(sid, { phase: "idle", http: cur.http, timer: setTimeout(() => teardown(sid), SESSION_TTL_MS) })
          }
          transport.close()
          throw err
        }
      })()

      sessions.set(sid, { phase: "spawning", http: s.http, timer, spawning })
      return spawning
    }
  }
}

const new_session = (sid: string): Session => {
  const session: Session = {
    phase: "idle",
    http: new StreamableHTTPServerTransport({
      sessionIdGenerator: () => sid,
      onsessionclosed: () => teardown(sid),
    }),
    timer: setTimeout(() => teardown(sid), SESSION_TTL_MS),
  }

  session.http.onmessage = async (msg) => {
    try {
      const stdio = await ensure(sid)
      await stdio.send(msg)
    } catch (err) {
      log(`forward: ${err}`)
    }
  }

  sessions.set(sid, session)
  return session
}

const ctrl = new AbortController()
const sig = { signal: ctrl.signal }

;(async () => {
  try {
    await Promise.race([once(process, "SIGTERM", sig), once(process, "SIGINT", sig)])
  } finally {
    ctrl.abort()
  }

  await Promise.all([
    ...Array.from(sessions, ([sid]) => teardown(sid)),
    new Promise((resolve, reject) => server.close((err) => (err ? reject(err) : resolve(undefined)))),
  ])
})()

const respond_error = (res: ServerResponse, status: number, code: number, message: string) => {
  res
    .writeHead(status, { "content-type": "application/json" })
    .end(JSON.stringify({ jsonrpc: "2.0", error: { code, message } } satisfies JSONRPCErrorResponse))
}

const server = createServer(async (req, res) => {
  const header = req.headers["mcp-session-id"]
  const sid = Array.isArray(header) ? header[0] : header

  let session: Session
  if (!sid) {
    const new_sid = randomUUID()
    session = new_session(new_sid)
  } else {
    const existing = sessions.get(sid)
    if (!existing) {
      respond_error(res, 404, -32001, "Session not found")
      return
    }
    session = existing
  }

  try {
    await session.http.handleRequest(req, res)
  } catch (err) {
    log(`handleRequest: ${err}`)
  }
}).listen(PORT)

await once(server, "listening", sig)
log(`:${PORT} → ${serverCmd} ${serverArgs.join(" ")}`)
