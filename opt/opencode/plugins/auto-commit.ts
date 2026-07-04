import { type Plugin } from "@opencode-ai/plugin"
import { access } from "node:fs/promises"
import { join } from "node:path"
import { execFileAsync, ROOT } from "./lib.ts"

const COMMIT = join(ROOT, "libexec", "worktree", "commit-on-change.sh")

export const auto_commit = (async ({ directory }) => ({
  event: async ({ event }) => {
    if (event["type"] !== "session.idle") {
      return
    }

    const notes = join(directory, ".notes")
    try {
      await access(join(notes, ".git"))
    } catch {
      return
    }

    await execFileAsync(COMMIT, [notes, "stop"])
  },
})) satisfies Plugin
