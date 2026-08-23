#!/usr/bin/env -S -- node

import { ok } from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { EOL } from "node:os"
import { dirname, extname, resolve } from "node:path"
import process, { argv, stderr } from "node:process"
import { fileURLToPath, pathToFileURL } from "node:url"

import { fullFormats } from "ajv-formats/dist/formats.js"
import { Ajv2020 } from "ajv/dist/2020.js"
import { Ajv } from "ajv/dist/ajv.js"
import { parse } from "yaml"

type Schema = Record<string, unknown>

const encoding = "utf8"
const schemaUri = {
  remote: /^https?:\/\//,
  meta: /^https?:\/\/json-schema\.org\/draft\//,
}

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

const schemaDocument = (uri: string, value: unknown): Schema => ({ ...schema(value), $id: uri })

const canonicalUri = (uri: string): string => {
  const location = new URL(uri)
  location.hash = ""
  return location.href
}

const readSchema = async (uri: string): Promise<Schema> => {
  const location = new URL(uri)
  location.hash = ""

  switch (location.protocol) {
    case "file:": {
      const path = fileURLToPath(location)
      const source = await readFile(path, encoding)
      return schemaDocument(location.href, parseSource(path, source))
    }
    case "http:":
    case "https:": {
      const response = await fetch(location)
      if (!response.ok) {
        throw new Error(`Unable to fetch schema: ${location.href} (${response.status} ${response.statusText})`)
      }

      const source = await response.text()
      const resolved = new URL(response.url)
      resolved.hash = ""
      return schemaDocument(resolved.href, parseSource(resolved.pathname, source))
    }
    default:
      throw new Error(`Unsupported schema URI: ${location.href}`)
  }
}

const loader = (): ((uri: string) => Promise<Schema>) => {
  const schemas = new Map<string, Promise<Schema>>()

  return async (uri: string): Promise<Schema> => {
    const key = canonicalUri(uri)
    const existing = schemas.get(key)
    if (existing !== undefined) {
      return existing
    }

    const loaded = readSchema(key)
    schemas.set(key, loaded)
    return loaded
  }
}

const schemaLocation = (path: string, declaration: string): string =>
  schemaUri.remote.test(declaration) ? declaration : pathToFileURL(resolve(dirname(path), declaration)).href

const ajvFor = (schemaDeclaration: string, loadSchema: (uri: string) => Promise<Schema>): Ajv | Ajv2020 => {
  const ajv = schemaDeclaration.includes("draft-07")
    ? new Ajv({ allErrors: true, loadSchema, strict: false })
    : new Ajv2020({ allErrors: true, loadSchema, strict: false })
  for (const [name, format] of Object.entries(fullFormats)) {
    ajv.addFormat(name, format)
  }
  return ajv
}

const validate = async (path: string, { source }: { source: string }): Promise<void> => {
  const data = parseSource(path, source)
  const declaration = modeline(source)
  const schemaDeclaration = declaration ?? schemaKey(data)
  if (schemaDeclaration === undefined) {
    return
  }

  const loadSchema = loader()
  const isSchema = schemaUri.meta.test(schemaDeclaration)
  const loaded = isSchema
    ? schemaDocument(pathToFileURL(path).href, data)
    : await loadSchema(schemaLocation(path, schemaDeclaration))
  const ajv = ajvFor(schemaKey(loaded) ?? "", loadSchema)
  const validator = await ajv.compileAsync(loaded)
  if (isSchema) {
    return
  }

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
