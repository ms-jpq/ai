#!/usr/bin/env -S -- node

import { once } from "node:events"
import { realpath, unlink } from "node:fs/promises"
import { createServer, type Socket } from "node:net"
import { join } from "node:path"
import process, { exit, stderr, stdin, stdout } from "node:process"
import { createInterface } from "node:readline"

const NAME = "wthread"
const SOCK = join(await realpath(".notes"), "channel.sock")

const TOOLS = [
  {
    name: "reply",
    description:
      "Send a line back to the CLI talking to this worker. Your transcript output never reaches it — only reply does.",
    inputSchema: {
      type: "object",
      properties: { text: { type: "string", description: "The line to send back." } },
      required: ["text"],
    },
  },
]

const send = (msg: object) => stdout.write(JSON.stringify({ jsonrpc: "2.0", ...msg }) + "\n")

const notify = (() => {
  let seq = 0
  return (content: string) => {
    const meta = { from: "cli", id: String(seq++), ts: String(Date.now()) }
    send({ method: "notifications/claude/channel", params: { content, meta } })
  }
})()

const clients = new Set<Socket>()

const serve = async (sock: string) => {
  await unlink(sock).catch(() => {})

  const server = createServer(async (s) => {
    clients.add(s)

    try {
      for await (const line of createInterface({ input: s })) {
        if (line.length > 0) {
          notify(line)
        }
      }
    } finally {
      clients.delete(s)
    }
  })

  server.on("error", (e) => {
    stderr.write(`${NAME}: ${e}\n`)
    exit(1)
  })

  server.listen(sock, () => stderr.write(`${NAME}: ${sock}\n`))
}

;(async () => {
  serve(SOCK)
})()

const error = (id: unknown, message: string) => send({ id, error: { code: -32601, message } })
const result = (id: unknown, result: object) => send({ id, result })
const broadcast = (text: string) => {
  const line = text.endsWith("\n") ? text : `${text}\n`
  for (const sock of clients) {
    sock.write(line)
  }
}
const dispatch = (line: string) => {
  const msg = JSON.parse(line)
  switch (msg.method) {
    case "ping":
      result(msg.id, {})
      break
    case "initialize":
      result(msg.id, {
        protocolVersion: msg.params?.protocolVersion ?? "2025-06-18",
        serverInfo: { name: NAME, version: "0.0.1" },
        capabilities: { tools: {}, experimental: { "claude/channel": {} } },
      })
      break
    case "tools/list":
      result(msg.id, { tools: TOOLS })
      break
    case "tools/call":
      if (msg.params?.name === "reply") {
        broadcast(String(msg.params.arguments?.text ?? ""))
        result(msg.id, { content: [{ type: "text", text: "sent" }] })
      } else {
        error(msg.id, `unknown tool: ${msg.params?.name}`)
      }
      break
    default:
      if ("id" in msg) {
        error(msg.id, `unknown method: ${msg.method}`)
      }
  }
}

{
  void (async () => {
    for await (const line of createInterface({ input: stdin })) {
      if (line.trim().length === 0) {
        continue
      }
      try {
        dispatch(line)
      } catch (e) {
        stderr.write(`${NAME}: ${e}\n`)
      }
    }
  })()
}

await Promise.race([once(process, "SIGINT"), once(process, "SIGTERM"), once(stdin, "end")])
await unlink(SOCK).catch(() => {})
exit(0)
