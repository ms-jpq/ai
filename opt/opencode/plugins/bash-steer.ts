import type { SyncHookJSONOutput } from "@anthropic-ai/claude-agent-sdk"
import { type Plugin } from "@opencode-ai/plugin"
import { join } from "node:path"
import { Readable } from "node:stream"
import { ROOT, spawning } from "./lib.ts"

const SCRIPT = join(ROOT, "opt", "claude-code", "hooks", "bash-steer.sh")

const block = (cmd: string, reason: string) => `>&2 printf -- '%s\\n' 'blocked: ${reason}' && exit 1; { ${cmd}; }`

export const bash_steer = (async () => ({
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash") {
      return
    }

    const { command } = output.args
    if (!command) {
      return
    }

    const payload = JSON.stringify({ tool_input: { command } })
    const text = await spawning({
      st: Readable.from([payload]),
      command: SCRIPT,
      options: { stdio: ["pipe", "pipe", null] },
    })

    if (!text.trim()) {
      return
    }

    const { hookSpecificOutput } = JSON.parse(text) as SyncHookJSONOutput
    if (hookSpecificOutput?.hookEventName !== "PreToolUse") {
      return
    }

    const { permissionDecision, permissionDecisionReason } = hookSpecificOutput
    if (permissionDecision !== "allow") {
      output.args["command"] = block(command, permissionDecisionReason ?? "blocked")
    }
  },
})) satisfies Plugin
