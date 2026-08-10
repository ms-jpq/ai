#!/usr/bin/env -S -- node

import { ok } from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { extname, resolve } from "node:path"
import { argv, exit } from "node:process"
import { fileURLToPath, pathToFileURL } from "node:url"

import Ajv2020 from "ajv/dist/2020.js"
import { parseDocument } from "yaml"

type Schema = Record<string, unknown>

const object = (value: unknown): Schema => {
  ok(typeof value === "object" && value !== null && !Array.isArray(value))
  return value
}

const parse = (source: string, path: string): unknown => {
  switch (extname(path)) {
    case ".json":
      return JSON.parse(source)
    case ".yaml":
    case ".yml": {
      const document = parseDocument(source)
      if (document.errors.length > 0) {
        throw document.errors[0]
      }
      return document.toJS()
    }
    default:
      throw new Error(`unsupported schema format: ${path}`)
  }
}

const read = async (path: string): Promise<Schema> => object(parse(await readFile(path, "utf8"), path))

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

const validate = async (schemaPath: string, dataPath: string | undefined): Promise<number> => {
  const path = resolve(schemaPath)
  const schema = { ...(await read(path)), $id: pathToFileURL(path).href }
  const ajv = new Ajv2020({ allErrors: true, loadSchema: loader() })
  const validator = await ajv.compileAsync(schema)

  if (dataPath === undefined) {
    process.stdout.write(`schema ${schemaPath} is valid\n`)
    return 0
  }

  const valid = validator(parse(await readFile(dataPath, "utf8"), dataPath))
  if (valid) {
    process.stdout.write(`${dataPath} valid\n`)
    return 0
  }

  process.stderr.write(`${dataPath} invalid\n${ajv.errorsText(validator.errors)}\n`)
  return 1
}

const main = async (): Promise<number> => {
  const [, , schemaPath, dataPath] = argv
  ok(schemaPath !== undefined)

  try {
    return await validate(schemaPath, dataPath)
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error)
    process.stderr.write(`schema ${schemaPath} is invalid\n${message}\n`)
    return 1
  }
}

exit(await main())
