import { type Plugin } from "@opencode-ai/plugin"

const RULES = {
  "invoke the command directly, shell indirection is unnecessary": [/^command\b/, /^eval\b/, /^exec\b/],
  "ask the user to escalate as needed": [/^gosu\b/, /^su\b/, /^sudo\b/, /^systemd-run\b/, /^run0\b/],
  "install locally, or ask the user to install system packages": [/^brew\b/, /^apt\b/, /^apt-get\b/, /^winget\b/],
  "use locally installed tools, install as required": [
    /^npx\b/,
    /^bunx\b/,
    /^pnpm\s+dlx\b/,
    /^yarn\s+dlx\b/,
    /^uvx\b/,
    /^pipx\s+run\b/,
  ],
  "use run_in_background for long-running work instead": [/^nohup\b/, /^screen\b/, /^zellij\b/, /^crontab\b/],
  "rely on the users already-running auth agent": [/^gpg-agent\b/, /^ssh-agent\b/],
  "review dangerous services command": [/^systemctl\b/, /^launchctl\b/],
  "review dangerous remote command": [/^ssh\b/, /^scp\b/, /^rsync\b/],
  "review dangerous gh command": [/^gh\s+.*\bdelete\b/, /^gh\s+.*\barchive\b/],
  "review dangerous terraform command": [/^terraform\b/],
  "review process killing": [/^kill\b/, /^killall\b/, /^pkill\b/],
  "review history rewriting": [/^git\s+rebase\b/, /^git\s+commit\s+.*--amend/],
}

const steer = (cmd: string): string | undefined => {
  for (const [reason, res] of Object.entries(RULES)) {
    if (res.some((re) => re.test(cmd))) {
      return reason
    }
  }
  return undefined
}

export const bash_steer = (async () => ({
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash") {
      return
    }

    const cmd: string = output.args.command?.trim()
    if (!cmd) {
      return
    }

    const reason = steer(cmd)
    if (reason !== undefined) {
      output.args["command"] = `>&2 printf -- '%s\\n' 'blocked: ${reason}' && exit 1`
    }
  },
})) satisfies Plugin
