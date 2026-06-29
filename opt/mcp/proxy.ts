#!/usr/bin/env -S -- node

import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js"
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js"
import { randomUUID } from "node:crypto"
import { once } from "node:events"
import { createServer } from "node:http"
import { EOL } from "node:os"
import { exit, stderr } from "node:process"
import { parseArgs } from "node:util"

type Session = {
  spawning?: Promise<StdioClientTransport>
  stdio?: StdioClientTransport
  timer?: ReturnType<typeof setTimeout>
}

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
sessions.getOrInsert =
  sessions.getOrInsert ??
  function (this: Map<string, Session>, key: string, value: Session): Session {
    if (this.has(key)) {
      return this.get(key)!
    }
    this.set(key, value)
    return value
  }

const teardown = async (sid: string) => {
  const s = sessions.get(sid) ?? {}
  sessions.delete(sid)

  if (s.timer) {
    clearTimeout(s.timer)
  }

  const closes = function* (): Generator<Promise<void>> {
    if (s.spawning) {
      yield s.spawning.then((t) => t.close())
      s.spawning = undefined
    }
    if (s.stdio) {
      yield s.stdio.close()
    }
  }

  await Promise.all(closes())
}

const ensure = async (sid: string): Promise<StdioClientTransport> => {
  const s = sessions.getOrInsert(sid, {})

  if (s.timer) {
    clearTimeout(s.timer)
  }
  s.timer = setTimeout(() => teardown(sid), SESSION_TTL_MS)

  if (s.stdio) {
    return s.stdio
  }

  s.spawning ??= (async () => {
    try {
      const transport = new StdioClientTransport({ command: serverCmd, args: serverArgs })

      transport.onclose = transport.onerror = () => {
        httpTransport.closeStandaloneSSEStream()
        s.stdio = undefined
      }

      transport.onmessage = async (msg) => {
        try {
          await httpTransport.send(msg)
        } catch (err) {
          log(`send: ${err}`)
        }
      }

      await transport.start()
      s.stdio = transport
      return transport
    } finally {
      s.spawning = undefined
    }
  })()

  return s.spawning
}

const httpTransport = (() => {
  const t = new StreamableHTTPServerTransport({
    sessionIdGenerator: () => randomUUID(),
    onsessionclosed: (sid: string) => teardown(sid),
  })

  t.onmessage = async (msg) => {
    const stdio = await ensure(t.sessionId!)
    await stdio.send(msg)
  }

  return t
})()

const ctrl = new AbortController()
const sig = { signal: ctrl.signal }

;(async () => {
  try {
    await Promise.race([once(process, "SIGTERM", sig), once(process, "SIGINT", sig)])
  } finally {
    ctrl.abort()
  }

  await Promise.all([
    httpTransport.close(),
    new Promise((resolve, reject) => server.close((err) => (err ? reject(err) : resolve(undefined)))),
    ...Array.from(sessions, ([sid]) => teardown(sid)),
  ])
})()

const server = createServer((req, res) => httpTransport.handleRequest(req, res)).listen(PORT)

await once(server, "listening", sig)
log(`:${PORT} → ${serverCmd} ${serverArgs.join(" ")}`)
