#!/usr/bin/env -S -- node

import { ok } from "node:assert/strict"
import { stdin, stdout } from "node:process"
import { text } from "node:stream/consumers"
import { finished } from "node:stream/promises"
import type { Nodes, Root, Table, TableCell, TableRow } from "mdast"
import { toString } from "mdast-util-to-string"

type RowsAndColumns = { columns: string[]; rows: string[][] }

const assertRoot: (value: unknown) => asserts value is Root = (value): void => {
  ok(typeof value === "object" && value !== null, "Expected an mdast root")
  ok("type" in value && value.type === "root", "Expected an mdast root")
  ok("children" in value && Array.isArray(value.children), "Expected root children")
}

const tables = function* (node: Nodes): IteratorObject<Table> {
  if (node.type === "table") {
    yield node
  } else if ("children" in node) {
    for (const child of node.children) {
      yield* tables(child)
    }
  }
  return
}

const cellText = (cell: TableCell): string => toString(cell, { includeImageAlt: false })

const rowText = ({ children }: TableRow): string[] => children.values().map(cellText).toArray()

const convertTable = ({ children }: Table): RowsAndColumns => {
  const [header, ...body] = children
  return {
    columns: header === undefined ? [] : rowText(header),
    rows: body.values().map(rowText).toArray(),
  }
}

const tree: unknown = JSON.parse(await text(stdin))
assertRoot(tree)

const result = tables(tree).map(convertTable).toArray()
stdout.end(`${JSON.stringify(result, undefined, 2)}\n`)
await finished(stdout)
