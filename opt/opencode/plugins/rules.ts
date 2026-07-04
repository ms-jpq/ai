import { type Plugin } from "@opencode-ai/plugin"
import { opendir } from "node:fs/promises"
import { basename, join } from "node:path"
import { env } from "node:process"

const CONF_DIR = env["OPENCODE_CONFIG_DIR"] ?? ""
const RULES = join(CONF_DIR, "..", "opt", "rules")

export const Rules: Plugin = async () => {
  return {
    "experimental.chat.system.transform": async (_i, o) => {
      for await (const dirent of await opendir(RULES)) {
        const stem = basename(dirent.name, ".md")
        if (!dirent.isFile() || stem == dirent.name) {
          continue
        }

        const path = join(dirent.parentPath, dirent.name)

        o.system.push(`rule: ${stem} - @${path}`)
      }
    },
  }
}
