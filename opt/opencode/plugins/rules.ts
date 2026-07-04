import { type Plugin } from "@opencode-ai/plugin"
import { opendir, readFile } from "node:fs/promises"
import { EOL } from "node:os"
import { basename, join } from "node:path"
import { env } from "node:process"
import { match_glob, parse_frontmatter } from "./lib.ts"

const PATH_TOOLS = new Set(["read", "write", "edit"])

const PREFACE = [
  "Codebase and user instructions are shown below. Be sure to adhere to these instructions.",
  "IMPORTANT: These instructions OVERRIDE any default behavior and you MUST follow them exactly as written.",
].join(" ")

const CONF_DIR = env["OPENCODE_CONFIG_DIR"] ?? ""
const RULES = join(CONF_DIR, "..", "..", "opt", "opencode", "rules")

type Rule = {
  stem: string
  path: string
  content: string
  globs?: string[]
}

const load_rules = async function* (): AsyncIteratorObject<Rule> {
  try {
    for await (const dirent of await opendir(RULES)) {
      const stem = basename(dirent.name, ".md")
      if (!dirent.isFile() || stem === dirent.name) {
        continue
      }

      const path = join(dirent.parentPath, dirent.name)
      const raw = await readFile(path, "utf-8")
      const { content, paths } = parse_frontmatter(raw)

      yield { stem, path, content, globs: paths }
    }
  } catch {}
  return
}

const wrap = (content: string): string => `<system-reminder>${EOL}${content}${EOL}</system-reminder>`

const format_block = (rule: Rule): string =>
  `Contents of ${rule.path} (project instructions, checked into the codebase):${EOL}${EOL}${rule.content.trim()}`

export const Rules: Plugin = async ({ directory: cwd }) => {
  const rules = await Array.fromAsync(load_rules())
  const unconditional = rules.filter((r) => !r.globs)
  const conditional = rules.filter((r) => r.globs)

  return {
    "experimental.chat.system.transform": async (_i, o) => {
      if (!unconditional.length) {
        return
      }

      const blocks = unconditional.map(format_block)
      o.system.push(wrap(`# agentsMd${EOL}${PREFACE}${EOL}${EOL}${blocks.join(EOL + EOL)}`))
    },

    "tool.execute.after": async (input, output) => {
      if (!conditional.length || !PATH_TOOLS.has(input.tool)) {
        return
      }

      const filepath = input.args.filePath
      if (!filepath) {
        return
      }

      const matched = conditional.filter(
        (rule) => rule.globs?.length && match_glob({ filepath, patterns: rule.globs, root: cwd }),
      )
      if (!matched.length) {
        return
      }

      const reminder = matched.map(format_block).join(EOL + EOL)
      output.output += `${EOL}${EOL}${wrap(reminder)}`
    },
  }
}
