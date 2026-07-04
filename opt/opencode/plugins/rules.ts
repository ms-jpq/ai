import { type Plugin } from "@opencode-ai/plugin"
import { opendir } from "node:fs/promises"
import { EOL } from "node:os"
import { basename, join } from "node:path"
import { env } from "node:process"

const CONF_DIR = env["OPENCODE_CONFIG_DIR"] ?? ""
const RULES = join(CONF_DIR, "..", "..", "opt", "opencode", "rules")

export const Rules: Plugin = async (_ctx) => {
  return {
    "experimental.chat.system.transform": async (_i, o) => {
      o.system.push(`${EOL}**Rules**:${EOL}`)

      for await (const dirent of await opendir(RULES)) {
        const stem = basename(dirent.name, ".md")
        if (!dirent.isFile() || stem == dirent.name) {
          continue
        }

        const path = join(dirent.parentPath, dirent.name)

        o.system.push(`rule: ${stem} → ${path}${EOL}`)
      }
    },
  }
}
