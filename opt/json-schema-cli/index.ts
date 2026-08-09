import { readFile } from "node:fs/promises"
import type { AnySchemaObject } from "ajv"
import { Ajv2020 } from "ajv/dist/2020.js"
import { default as addFormats } from "ajv-formats"

type Formats = (ajv: Ajv2020) => unknown

export type Input = { data: unknown; schema: URL }

export type Validation = { kind: "invalid"; errors: readonly string[]; schema: URL } | { kind: "valid"; schema: URL }

const is_schema = (value: unknown): value is AnySchemaObject =>
  typeof value === "object" && value !== undefined && value !== null && !Array.isArray(value)

const is_formats = (value: unknown): value is Formats => typeof value === "function"

const loadSchema = async (uri: string): Promise<AnySchemaObject> => {
  const url = new URL(uri)
  const schema = await (async (): Promise<unknown> => {
    switch (url.protocol) {
      case "file:":
        return JSON.parse(await readFile(url, "utf8"))
      case "http:":
      case "https:": {
        const response = await fetch(url)
        if (!response.ok) {
          throw new Error(`could not load schema ${url}: ${response.status} ${response.statusText}`)
        }
        return response.json()
      }
      default:
        throw new Error(`unsupported schema protocol: ${url.protocol}`)
    }
  })()
  if (!is_schema(schema)) {
    throw new Error(`schema ${url} is not an object`)
  }
  return schema
}

const validate = async ({ data, schema }: Input): Promise<Validation> => {
  const ajv = new Ajv2020({ allErrors: true, loadSchema, strict: false })
  const formats: unknown = addFormats
  if (!is_formats(formats)) {
    throw new Error("could not load ajv formats")
  }
  formats(ajv)
  const validator = await ajv.compileAsync({ $ref: schema.href })
  const valid = validator(data)
  const errors = (validator.errors ?? []).map(
    ({ instancePath, message }) => `${instancePath || "/"} ${message ?? "is invalid"}`,
  )

  return valid ? { kind: "valid", schema } : { kind: "invalid", errors, schema }
}

export default validate
