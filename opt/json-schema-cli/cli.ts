#!/usr/bin/env -S -- node

import { ok } from "node:assert/strict"
import { parseArgs } from "node:util"

const { positionals } = parseArgs({ allowPositionals: true, strict: true })
const [path] = positionals

ok(path)
ok(positionals.length === 1)

const imp = async () => {
  try {
    return (await import("./index.ts")).default
  } catch {
    return undefined
  }
}

const validate = await imp()
if (validate) {
  await validate(path)
}
