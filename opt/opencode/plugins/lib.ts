import { exec, execFile, spawn, type SpawnOptions } from "node:child_process"
import { createWriteStream } from "node:fs"
import { devNull, EOL } from "node:os"
import { join } from "node:path"
import { Readable } from "node:stream"
import { text } from "node:stream/consumers"
import { pipeline } from "node:stream/promises"
import { promisify } from "node:util"

export const encoding = "utf-8" satisfies BufferEncoding

export const ROOT = join(import.meta.dirname, "..", "..", "..")

export type parsed_frontmatter = { content: string; paths?: string[] }

export const execFileAsync = promisify(execFile)
export const execAsync = promisify(exec)

export const spawning = async ({
  st,
  command,
  args = [],
  options = {},
}: {
  st: Readable
  command: string
  args?: readonly string[]
  options?: SpawnOptions
}): Promise<string> => {
  const ctrl = new AbortController()
  options.signal = ctrl.signal
  const { stdin, stdout } = spawn(command, args, options)

  try {
    const [, txt] = await Promise.all([
      pipeline(st, stdin ?? createWriteStream(devNull), { signal: ctrl.signal }),
      text(stdout ?? Readable.from("")),
    ])
    return txt
  } finally {
    ctrl.abort()
  }
}

const trim_item = (line: string): string => line.replace(/^\s*-\s*["']?(.*?)["']?\s*$/, "$1").trim()

const strip_star_star = (p: string): string => (p.endsWith("/**") ? p.slice(0, -3) : p)

const extract_paths = (yaml: string): string[] | undefined => {
  const match = /^paths:\s*\n((?:\s+-\s+.+\n?)*)/m.exec(yaml)

  const patterns = (match?.[1] ?? "")
    .split(EOL)
    .values()
    .map(trim_item)
    .filter(Boolean)
    .map(strip_star_star)
    .filter((p) => p.length > 0)
    .toArray()

  return !patterns.length || patterns.every((p) => p === "**") ? undefined : patterns
}

export const parse_frontmatter = (text: string): parsed_frontmatter => {
  if (!text.startsWith("---\n")) {
    return { content: text }
  }

  const close = text.indexOf("\n---\n", 4)
  if (close === -1) {
    return { content: text }
  }

  const frontmatter = text.slice(4, close)
  const content = text.slice(close + 5)
  const paths = extract_paths(frontmatter)

  return paths ? { content, paths } : { content }
}

const glob_to_regex = (pattern: string): RegExp => {
  let result = "^"
  let i = 0
  while (i < pattern.length) {
    const ch = pattern[i]
    if (ch === undefined) break

    const next = pattern[i + 1]
    const after = pattern[i + 2]
    if (ch === "*" && next === "*") {
      result += after === "/" ? "(?:.*/)?" : ".*"
      i += after === "/" ? 3 : 2
    } else if (ch === "*") {
      result += "[^/]*"
      i++
    } else if (ch === "?") {
      result += "[^/]"
      i++
    } else if (ch === "{") {
      const close = pattern.indexOf("}", i)
      if (close === -1) {
        result += "\\{"
        i++
      } else {
        const inner = pattern.slice(i + 1, close)
        const parts = inner.split(",").map((s) => s.replace(/[.()+-^${}[\]|\\]/g, "\\$&"))
        result += `(${parts.join("|")})`
        i = close + 1
      }
    } else if (".()+-^${}[]|\\".includes(ch)) {
      result += "\\" + ch
      i++
    } else {
      result += ch
      i++
    }
  }
  result += "$"
  return new RegExp(result)
}

export const match_glob = ({
  filepath,
  patterns,
  root,
}: {
  filepath: string
  patterns: string[]
  root: string
}): boolean => {
  const relative = filepath.startsWith(root) ? filepath.slice(root.length + 1) : filepath

  return patterns.some((pattern) => glob_to_regex(pattern).test(relative))
}
