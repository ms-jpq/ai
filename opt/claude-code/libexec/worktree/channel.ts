#!/usr/bin/env -S -- node

import type {
  CallToolResult,
  InitializeResult,
  JSONRPCErrorResponse,
  JSONRPCNotification,
  JSONRPCResultResponse,
  ListToolsResult,
  RequestId,
  Result,
  Tool,
} from "@modelcontextprotocol/sdk/types.js"
import { once } from "node:events"
import { realpath, unlink } from "node:fs/promises"
import { createServer, type Socket } from "node:net"
import { join } from "node:path"
import process, { exit, stderr, stdin, stdout } from "node:process"
import { createInterface } from "node:readline"

const NAME = "wt"

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
] satisfies Tool[]

const clients = new Set<Socket>()

const send = (
  msg:
    | Omit<JSONRPCResultResponse, "jsonrpc">
    | Omit<JSONRPCErrorResponse, "jsonrpc">
    | Omit<JSONRPCNotification, "jsonrpc">,
) => stdout.write(JSON.stringify({ jsonrpc: "2.0", ...msg }) + "\n")

const error = (id: RequestId, message: string) => send({ id, error: { code: -32601, message } })

const respond = (id: RequestId, result: Result) => send({ id, result })

const notify = (() => {
  let seq = 0
  return (content: string) => {
    const meta = { from: "cli", id: String(seq++), ts: String(Date.now()) }
    send({ method: "notifications/claude/channel", params: { content, meta } })
  }
})()

const broadcast = (text: string) => {
  const line = text.endsWith("\n") ? text : `${text}\n`
  for (const sock of clients) {
    sock.write(line)
  }
}

const dispatch = (line: string) => {
  const msg = JSON.parse(line) as { method: string; id: RequestId; params?: any }

  switch (msg.method) {
    case "ping":
      respond(msg.id, {})
      break
    case "initialize":
      respond(msg.id, {
        protocolVersion: msg.params?.protocolVersion ?? "2025-06-18",
        serverInfo: { name: NAME, version: "0.0.1" },
        capabilities: { tools: {}, experimental: { "claude/channel": {} } },
      } satisfies InitializeResult)
      break
    case "tools/list":
      respond(msg.id, { tools: TOOLS } satisfies ListToolsResult)
      break
    case "tools/call":
      if (msg.params?.name === "reply") {
        broadcast(String(msg.params.arguments?.text ?? ""))
        respond(msg.id, { content: [{ type: "text", text: "sent" }] } satisfies CallToolResult)
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

const listen = async () => {
  for await (const line of createInterface({ input: stdin })) {
    if (line.length === 0) {
      continue
    }

    try {
      dispatch(line)
    } catch (e) {
      stderr.write(`${NAME}: ${e}\n`)
    }
  }
}

const serve = async (sock: string) => {
  await unlink(sock).catch(() => {})

  const server = createServer(async (s) => {
    clients.add(s)

    try {
      for await (const line of createInterface({ input: s })) {
        if (line.length) {
          notify(line)
        }
      }
    } catch (_) {
    } finally {
      clients.delete(s)
    }
  })

  await Promise.all([
    new Promise<void>((r) => server.listen(sock, r)),
    once(server, "error").then(([e]) => {
      throw e
    }),
  ])
}

const main = async () => {
  const sock = join(await realpath(".notes"), "channel.sock")

  try {
    await Promise.race([once(process, "SIGINT"), once(process, "SIGTERM"), listen(), serve(sock)])
  } finally {
    await unlink(sock).catch(() => {})
  }
}

await main()
exit(0)
