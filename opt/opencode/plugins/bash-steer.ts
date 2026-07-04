import { type Plugin } from "@opencode-ai/plugin"

const RULES = new Map<RegExp[], string>([
  [[/^command\b/, /^eval\b/, /^exec\b/], "invoke the command directly, shell indirection is unnecessary"],
  [[/^gosu\b/, /^su\b/, /^sudo\b/, /^systemd-run\b/, /^run0\b/], "ask the user to escalate as needed"],
  [[/^brew\b/, /^apt\b/, /^apt-get\b/, /^winget\b/], "install locally, or ask the user to install system packages"],
  [[/^npx\b/, /^bunx\b/, /^pnpm\s+dlx\b/, /^yarn\s+dlx\b/, /^uvx\b/, /^pipx\s+run\b/], "use locally installed tools, install as required"],
  [[/^nohup\b/, /^screen\b/, /^zellij\b/, /^crontab\b/], "use run_in_background for long-running work instead"],
  [[/^gpg-agent\b/, /^ssh-agent\b/], "rely on the users already-running auth agent"],
  [[/^systemctl\b/, /^launchctl\b/], "review dangerous services command"],
  [[/^ssh\b/, /^scp\b/, /^rsync\b/], "review dangerous remote command"],
  [[/^gh\s+.*\bdelete\b/, /^gh\s+.*\barchive\b/], "review dangerous gh command"],
  [[/^terraform\b/], "review dangerous terraform command"],
  [[/^kill\b/, /^killall\b/, /^pkill\b/], "review process killing"],
  [[/^git\s+rebase\b/, /^git\s+commit\s+.*--amend/], "review history rewriting"],
])

const steer = (cmd: string): string | undefined => {
  for (const [res, reason] of RULES) {
    if (res.some((re) => re.test(cmd))) {
      return reason
    }
  }
  return undefined
}

export const bash_steer = (async () => ({
  "command.execute.before": async (input, _output) => {
    const cmd: string = input.arguments.trim()
    const reason = steer(cmd)
    if (reason !== undefined) {
      throw new Error(`${reason} — "${cmd}"`)
    }
  },
})) satisfies Plugin
