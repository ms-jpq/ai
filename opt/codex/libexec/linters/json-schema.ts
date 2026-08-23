#!/usr/bin/env -S -- node

import { ok } from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { EOL } from "node:os"
import { dirname, extname, resolve } from "node:path"
import process, { argv, stderr } from "node:process"
import { fileURLToPath, pathToFileURL } from "node:url"

import { Ajv2020 } from "ajv/dist/2020.js"
import { parse } from "yaml"

type Schema = Record<string, unknown>

const encoding = "utf8"

const parseSource = (path: string, source: string): unknown => {
  switch (extname(path)) {
    case ".json":
      return JSON.parse(source)
    case ".yaml":
    case ".yml":
      return parse(source, { merge: true })
    default:
      return {}
  }
}

const schema = (value: unknown): Schema => {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    ok(false)
  }
  return Object.fromEntries(Object.entries(value))
}

const modeline = (source: string): string | undefined => {
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

const document = (path: string, value: unknown): Schema => ({ ...schema(value), $id: pathToFileURL(path).href })

const readSchema = async (path: string): Promise<Schema> => {
  const source = await readFile(path, encoding)
  return document(path, parseSource(path, source))
}

const loader = (): ((uri: string) => Promise<Schema>) => {
  const schemas = new Map<string, Schema>()

  return async (uri: string): Promise<Schema> => {
    const path = fileURLToPath(uri)
    const existing = schemas.get(path)
    if (existing !== undefined) {
      return existing
    }

    const loaded = await readSchema(path)
    schemas.set(path, loaded)
    return loaded
  }
}

const validate = async (path: string, { source }: { source: string }): Promise<void> => {
  const data = parseSource(path, source)
  const declaration = modeline(source)
  const schemaDeclaration = declaration ?? schemaKey(data)
  if (schemaDeclaration === undefined) {
    return
  }

  const ajv = new Ajv2020({ allErrors: true, loadSchema: loader() })
  if (schemaDeclaration.startsWith("https://json-schema.org/draft/")) {
    await ajv.compileAsync(document(path, data))
    return
  }

  if (schemaDeclaration.startsWith("https://")) {
    return
  }

  const schemaPath = resolve(dirname(path), schemaDeclaration)
  const validator = await ajv.compileAsync(await readSchema(schemaPath))
  if (!validator(data)) {
    throw new Error(ajv.errorsText(validator.errors))
  }
}

const main = async (): Promise<number> => {
  const [, , dataPath] = argv
  ok(dataPath !== undefined)

  try {
    const path = resolve(dataPath)
    const source = await readFile(path, encoding)
    await validate(path, { source })
    return 0
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error)
    stderr.write(`Invalid: ${dataPath}${EOL}${message}${EOL}`)
    return 1
  }
}

process.exitCode = await main()
