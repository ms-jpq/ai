import { describe, it } from "node:test"
import { deepEqual, equal, ok } from "node:assert/strict"
import { match_glob, parse_frontmatter } from "./lib.ts"

describe("parse_frontmatter", { concurrency: true }, () => {
  it("returns text as content when no frontmatter", () => {
    const result = parse_frontmatter("# Hello\n\nWorld")
    equal(result.content, "# Hello\n\nWorld")
    ok(result.paths === undefined)
  })

  it("returns text as content when frontmatter has no closing delimiter", () => {
    const result = parse_frontmatter("---\ntitle: test\n# Content")
    equal(result.content, "---\ntitle: test\n# Content")
  })

  it("strips frontmatter and returns content without paths", () => {
    const raw = "---\ntitle: test\n---\n\n# Content"
    const result = parse_frontmatter(raw)
    equal(result.content, "\n# Content")
    ok(result.paths === undefined)
  })

  it("extracts paths from frontmatter", () => {
    const raw = "---\npaths:\n  - \"src/**/*.ts\"\n  - 'api/*.ts'\n---\n\n# Content"
    const result = parse_frontmatter(raw)
    equal(result.content, "\n# Content")
    deepEqual(result.paths, ["src/**/*.ts", "api/*.ts"])
  })

  it("strips /** suffix from paths", () => {
    const raw = "---\npaths:\n  - src/**\n---\n\n# Content"
    const result = parse_frontmatter(raw)
    deepEqual(result.paths, ["src"])
  })

  it("returns undefined paths when all patterns are **", () => {
    const raw = "---\npaths:\n  - '**'\n---\n\n# Content"
    const result = parse_frontmatter(raw)
    ok(result.paths === undefined)
  })
})

describe("match_glob", { concurrency: true }, () => {
  const root = "/some/project"
  const match = ({ filepath, patterns }: { filepath: string; patterns: string[] }) =>
    match_glob({ filepath, patterns, root })

  it("exact path match relative to root", () => {
    ok(match({ filepath: "/some/project/src/main.ts", patterns: ["src/main.ts"] }))
  })

  it("single-segment wildcard", () => {
    ok(match({ filepath: "/some/project/src/main.ts", patterns: ["src/*.ts"] }))
  })

  it("multi-segment wildcard", () => {
    ok(match({ filepath: "/some/project/src/nested/main.ts", patterns: ["src/**/*.ts"] }))
    ok(match({ filepath: "/some/project/src/main.ts", patterns: ["src/**/*.ts"] }))
  })

  it("question mark wildcard", () => {
    ok(match({ filepath: "/some/project/test/a1.ts", patterns: ["test/a?.ts"] }))
  })

  it("brace expansion — *.{ts,js}", () => {
    ok(match({ filepath: "/some/project/src/main.ts", patterns: ["src/*.{ts,js}"] }))
    ok(match({ filepath: "/some/project/src/main.js", patterns: ["src/*.{ts,js}"] }))
  })

  it("brace expansion rejects non-matching extension", () => {
    ok(!match({ filepath: "/some/project/src/main.css", patterns: ["src/*.{ts,js}"] }))
  })

  it("brace expansion with **", () => {
    ok(match({ filepath: "/some/project/src/a/b/main.ts", patterns: ["src/**/*.{ts,tsx}"] }))
  })

  it("rejects non-matching path", () => {
    ok(!match({ filepath: "/some/project/docs/readme.md", patterns: ["src/**/*.ts"] }))
  })

  it("rejects path outside root", () => {
    ok(!match({ filepath: "/other/project/src/main.ts", patterns: ["src/**"] }))
  })

  it("matches any of multiple patterns", () => {
    ok(
      match({
        filepath: "/some/project/docs/api.md",
        patterns: ["src/**/*.ts", "docs/**/*.md"],
      }),
    )
  })

  it("rejects when no pattern matches", () => {
    ok(
      !match({
        filepath: "/some/project/config.yml",
        patterns: ["src/**/*.ts", "docs/**/*.md"],
      }),
    )
  })
})
