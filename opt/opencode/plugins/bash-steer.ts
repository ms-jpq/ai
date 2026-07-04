import { type Plugin } from "@opencode-ai/plugin"
import { execSync } from "node:child_process"
import { join } from "node:path"
import { ROOT } from "./lib.ts"

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
    const text = execSync(SCRIPT, { input: payload, encoding: "utf8", timeout: 2000 }).trimEnd()
    if (!text) {
      return
    }

    const parsed = JSON.parse(text)
    const decision = parsed.hookSpecificOutput?.permissionDecision
    const reason = parsed.hookSpecificOutput?.permissionDecisionReason ?? "blocked"
    if (decision === "deny" || decision === "ask") {
      output.args["command"] = block(command, reason)
    }
  },
})) satisfies Plugin
