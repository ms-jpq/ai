import { type Plugin } from "@opencode-ai/plugin"
import { opendir, readFile } from "node:fs/promises"
import { EOL } from "node:os"
import { basename, join } from "node:path"
import { encoding, execFileAsync, ROOT } from "./lib.ts"

const PATH_TOOLS = new Set(["read", "write", "edit"])

const LIBEXEC = join(ROOT, "opt", "codex", "libexec")
const PARSE_PATHS = join(LIBEXEC, "frontmatter-path.sed")
const MATCH_PATH = join(LIBEXEC, "frontmatter-path-match.sh")
const PREFACE_PATH = join(ROOT, "opt", "codex", "libexec", "rules-preface.txt")
const RULES = join(ROOT, "opt", "opencode", "rules")

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
      const raw = await readFile(path, encoding)
      const { stdout } = await execFileAsync(PARSE_PATHS, [path], { encoding })
      const globs = stdout.trim().split(EOL).filter(Boolean)
      const content = raw.replace(/^---\n.*?\n---\n/s, "")

      yield { stem, path, content, globs: globs.length ? globs : undefined }
    }
  } catch {}
  return
}

const wrap = (content: string): string => `<system-reminder>${EOL}${content}${EOL}</system-reminder>`

const format_block = (rule: Rule): string =>
  `Contents of ${rule.path} (project instructions, checked into the codebase):${EOL}${EOL}${rule.content.trim()}`

export const rules = (async () => {
  const rules = await Array.fromAsync(load_rules())
  const unconditional = rules.filter((r) => !r.globs)
  const conditional = rules.filter((r) => r.globs)

  const preface = await readFile(PREFACE_PATH, encoding)

  const sent = new Set<string>()

  return {
    "experimental.chat.system.transform": async (_i, o) => {
      if (!unconditional.length) {
        return
      }

      const blocks = unconditional.map(format_block)
      o.system.push(wrap(`# agentsMd${EOL}${preface.trim()}${EOL}${EOL}${blocks.join(EOL + EOL)}`))
    },

    "experimental.session.compacting": async () => {
      sent.clear()
    },

    "tool.execute.after": async (input, output) => {
      if (!conditional.length || !PATH_TOOLS.has(input.tool)) {
        return
      }

      const filepath = input.args.filePath
      if (!filepath) {
        return
      }

      const unsent = (
        await Promise.all(
          conditional
            .values()
            .filter((rule) => !sent.has(rule.stem))
            .map(async (rule) => {
              try {
                await execFileAsync(MATCH_PATH, [filepath, ...(rule.globs ?? [])])
                return rule
              } catch {
                return undefined
              }
            }),
        )
      ).filter((rule) => rule !== undefined)
      if (!unsent.length) {
        return
      }

      for (const rule of unsent) {
        sent.add(rule.stem)
      }

      const reminder = unsent.map(format_block).join(EOL + EOL)
      output.output += `${EOL}${EOL}${wrap(reminder)}`
    },
  }
}) satisfies Plugin
