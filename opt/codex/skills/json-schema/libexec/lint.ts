#!/usr/bin/env -S -- node

import { ok } from "node:assert/strict"
import { execFile as execFile_ } from "node:child_process"
import { resolve } from "node:path"
import { argv, exit } from "node:process"
import { fileURLToPath, pathToFileURL } from "node:url"
import { promisify } from "node:util"

import Ajv2020 from "ajv/dist/2020.js"

type Schema = Record<string, unknown>

const encoding = "utf8"
const execFile = promisify(execFile_)

const object = (value: unknown): Schema => {
  ok(typeof value === "object" && value !== null && !Array.isArray(value))
  return value
}

const parse = async (path: string): Promise<unknown> => {
  const { stdout } = await execFile(
    "yq",
    ["--yaml-fix-merge-anchor-to-spec", "--output-format=json", "--unwrapScalar=false", ".", "--", path],
    { encoding },
  )
  return JSON.parse(stdout)
}

const read = async (path: string): Promise<Schema> => object(await parse(path))

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

  const valid = validator(await parse(dataPath))
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
