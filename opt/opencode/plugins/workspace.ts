import { type Plugin, type WorkspaceAdapter, type WorkspaceInfo } from "@opencode-ai/plugin"
import { join } from "node:path"
import { cwd } from "node:process"
import { encoding, execAsync, execFileAsync, ROOT } from "./lib.ts"
const POOL = join(ROOT, "opt", "codex", "libexec", "worktree", "pool.sh")

const resolveRoot = async (config: WorkspaceInfo): Promise<string> => {
  const result = await execAsync("git rev-parse --show-toplevel", {
    cwd: config.directory ?? cwd(),
    encoding,
  })
  return result["stdout"].trim()
}

const adapter = {
  name: "worktree",
  description: "git worktree",

  configure: async (config) => config,

  create: async (config) => {
    await execFileAsync(POOL, ["add", config.name], { cwd: await resolveRoot(config) })
  },

  remove: async (config) => {
    await execFileAsync(POOL, ["remove", config.name], { cwd: await resolveRoot(config) })
  },

  target: async (config) => ({
    type: "local",
    directory: join(await resolveRoot(config), ".worktrees", config.name),
  }),
} satisfies WorkspaceAdapter

export const workspace = (async ({ experimental_workspace }) => {
  experimental_workspace.register("worktree", adapter)
  return {}
}) satisfies Plugin
