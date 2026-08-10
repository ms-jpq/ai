#!/usr/bin/env -S -- node

import { ok } from "node:assert/strict"
import { execFile as execFile_ } from "node:child_process"
import { readFile } from "node:fs/promises"
import { EOL } from "node:os"
import { dirname, resolve } from "node:path"
import { argv, exit, stderr } from "node:process"
import { fileURLToPath, pathToFileURL } from "node:url"
import { promisify } from "node:util"

import { Ajv2020 } from "ajv/dist/2020.js"

type Schema = Record<string, unknown>

const encoding = "utf8"
const execFile = promisify(execFile_)

const parse = async (path: string): Promise<unknown> => {
  const { stdout } = await execFile(
    "yq",
    ["--yaml-fix-merge-anchor-to-spec", "--output-format=json", "--unwrapScalar=false", ".", "--", path],
    { encoding },
  )
  return JSON.parse(stdout)
}

const schema = (value: unknown): Schema => {
  ok(typeof value === "object" && value !== null && !Array.isArray(value))
  return Object.fromEntries(Object.entries(value))
}

const modeline = async (path: string): Promise<string | undefined> => {
  const source = await readFile(path, encoding)
  const [first = ""] = source.split(EOL, 1)
  const lsp = /^\s*(?:#|\/\/)?\s*(?:yaml|json)-language-server:\s*\$schema=(\S+)\s*$/.exec(first)
  const taplo = /^\s*#:schema\s+(\S+)\s*$/.exec(first)
  return lsp?.[1] ?? taplo?.[1]
}

const schemaKey = (value: unknown): string | undefined => {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return undefined
  }

  const entry = Object.entries(value).find(([key]: [string, unknown]): boolean => key === "$schema")
  if (entry === undefined) {
    return undefined
  }

  const [, declaration] = entry
  return typeof declaration === "string" ? declaration : undefined
}

const read = async (path: string): Promise<Schema> => schema(await parse(path))

const loader = (): ((uri: string) => Promise<Schema>) => {
  const schemas = new Map<string, Schema>()

  return async (uri: string): Promise<Schema> => {
    const path = fileURLToPath(uri)
    const existing = schemas.get(path)
    if (existing !== undefined) {
      return existing
    }

    const schema = { ...(await read(path)), $id: pathToFileURL(path).href }
    schemas.set(path, schema)
    return schema
  }
}

const validate = async (dataPath: string): Promise<number> => {
  const path = resolve(dataPath)
  const [data, declaration] = await Promise.all([parse(path), modeline(path)])
  const schemaDeclaration = declaration ?? schemaKey(data)
  if (schemaDeclaration === undefined) {
    return 0
  }

  const ajv = new Ajv2020({ allErrors: true, loadSchema: loader() })
  if (schemaDeclaration.startsWith("https://json-schema.org/draft/")) {
    await ajv.compileAsync({ ...schema(data), $id: pathToFileURL(path).href })
    return 0
  }

  const schemaPath = resolve(dirname(path), schemaDeclaration)
  const validator = await ajv.compileAsync({ ...(await read(schemaPath)), $id: pathToFileURL(schemaPath).href })
  const valid = validator(data)
  if (valid) {
    return 0
  }

  stderr.write(`${dataPath} invalid${EOL}${ajv.errorsText(validator.errors)}${EOL}`)
  return 1
}

const main = async (): Promise<number> => {
  const [, , dataPath] = argv
  ok(dataPath !== undefined)

  try {
    return await validate(dataPath)
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error)
    stderr.write(`${dataPath} invalid${EOL}${message}${EOL}`)
    return 1
  }
}

exit(await main())
