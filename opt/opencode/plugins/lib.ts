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
