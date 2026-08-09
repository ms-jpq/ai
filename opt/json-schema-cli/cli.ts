#!/usr/bin/env -S -- node

import { ok } from "node:assert/strict"
import { readFile } from "node:fs/promises"
import { extname, resolve } from "node:path"
import { exit } from "node:process"
import { pathToFileURL } from "node:url"
import { parseArgs } from "node:util"

type Discovery = { kind: "none" } | { kind: "schema"; uri: URL } | { kind: "disabled" }

type Format = "json" | "toml" | "yaml"

const format = (path: string): Format => {
  switch (extname(path)) {
    case ".json":
      return "json"
    case ".toml":
      return "toml"
    case ".yaml":
    case ".yml":
      return "yaml"
    default:
      throw new Error(`unsupported file extension: ${path}`)
  }
}

const header = (source: string): readonly string[] => {
  const lines = source.split(/\r?\n/u)
  const end = lines.findIndex((line) => !/^\s*(?:#.*)?$/u.test(line))
  return lines.slice(0, end < 0 ? undefined : end)
}

const relative_url = (value: string, path: string): URL => new URL(value, pathToFileURL(resolve(path)))

const modeline = (source: string, path: string, input: Format): Discovery => {
  const expression =
    input === "yaml"
      ? /^\s*#\s*(?:yaml-language-server:\s*)?\$schema\s*(?::|=)\s*(\S+)\s*$/u
      : /^\s*#:\s*schema\s+(\S+)\s*$/u
  const value = header(source)
    .map((line) => line.match(expression)?.[1])
    .find((entry) => entry !== undefined)

  if (value === undefined) {
    return { kind: "none" }
  }
  if (value === "none") {
    return { kind: "disabled" }
  }
  return { kind: "schema", uri: relative_url(value, path) }
}

const schema_key = (value: unknown, path: string): Discovery => {
  if (typeof value !== "object" || value === undefined || value === null) {
    return { kind: "none" }
  }
  const schema = Reflect.get(value, "$schema")
  if (typeof schema !== "string") {
    return { kind: "none" }
  }
  return schema === "none" ? { kind: "disabled" } : { kind: "schema", uri: relative_url(schema, path) }
}

const imp = async <T>(load: () => Promise<T>): Promise<T | undefined> => {
  try {
    return await load()
  } catch {
    return undefined
  }
}

const { positionals } = parseArgs({ allowPositionals: true, strict: true })
const [path] = positionals

ok(path)
ok(positionals.length === 1)

const source = await readFile(path, "utf8")
const input = format(path)

const parser = await imp(async (): Promise<(source: string) => unknown> => {
  switch (input) {
    case "json":
      return JSON.parse
    case "toml": {
      const toml = await import("@iarna/toml")
      return toml.parse
    }
    case "yaml": {
      const yaml = await import("yaml")
      return (text) => {
        const document = yaml.parseDocument(text)
        if (document.errors.length > 0) {
          throw document.errors[0]
        }
        return document.toJS()
      }
    }
  }
})

if (parser === undefined) {
  exit(0)
}

const declaration = input === "json" ? { kind: "none" } : modeline(source, path, input)
const discovery = declaration.kind === "none" ? schema_key(parser(source), path) : declaration
if (discovery.kind !== "schema") {
  exit(0)
}

const validator = await imp(() => import("./index.ts"))
if (validator === undefined) {
  exit(0)
}

await validator.default({ data: parser(source), schema: discovery.uri })
