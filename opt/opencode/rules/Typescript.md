---
paths:
  - "*.cjs"
  - "*.cts"
  - "*.js"
  - "*.jsx"
  - "*.mjs"
  - "*.mts"
  - "*.ts"
  - "*.tsx"
---

# TypeScript

## Defaults

- Annotate every function signature. Otherwise, add annotations only when inference loses required precision.

- Prefer `const` to `let`. Replace reassignment with conditional expressions, destructuring, `.entries()`, or intermediate constants.

- Use `undefined` consistently; do not use `null`.

- Use `import type` for type-only imports.

---

## Functions

- Prefer `const foo = () => {}` to `function foo() {}`.

- Define generators with `const foo = function*() {}`. Use `IteratorObject<T>` for synchronous generators and `AsyncIteratorObject<T>` for asynchronous generators.

  - End generator bodies with an explicit `return`.

  ```typescript
  const chunks = function* <T>(items: readonly T[], size: number): IteratorObject<readonly T[]> {
    for (let index = 0; index < items.length; index += size) {
      yield items.slice(index, index + size)
    }
    return
  }
  ```

- After the primary operand, pass arguments through one destructured parameters object. Inline its type unless shared.

  ```typescript
  const read = (path: string, { limit = 100 }: { limit?: number }) => {}
  ```

---

## Types

- Narrow unknown input at the boundary with control flow, not casts.

- Use `satisfies` to validate a shape without widening inferred literal types.

  ```typescript
  const status = { kind: "ready", retryable: false } satisfies Status
  ```

- Attach metadata to domain types with `unique symbol` keys.

  ```typescript
  const META: unique symbol = Symbol("meta")
  type Decorated = Base & { [META]: Meta }
  ```

---

## Data Access

- Destructure records and tuples before using their values.

  ```typescript
  const {
    id,
    tags: [firstTag, ...restTags],
  } = item
  ```

- Use indexed access only for optional or nil-tolerant lookup.

  ```typescript
  const item = items.get(id)
  ```

- Use `??` immediately after optional access when a local default is intended. Reserve `||` for boolean short-circuiting.

---

## Transforms

- Chain collection transforms instead of mutating an accumulator.

- Use `Object.entries()`, `Object.fromEntries()`, `Object.groupBy()`, and `Map.groupBy()` for object-shaped transforms.

  ```typescript
  const byKind = Map.groupBy(
    items.filter((item) => item.enabled).map((item) => ({ kind: item.kind, name: item.name })),
    (item) => item.kind,
  )
  ```

---

## State

- Use IIFEs `(() => {})()` for small conversions that need lexical encapsulation and an inline expression result.

  ```typescript
  const label = (() => {
    const trimmed = value.trim()
    return trimmed === "" ? "untitled" : trimmed
  })()
  ```

- Model stateful objects with closures instead of classes:

  ```typescript
  const buffer = <T>() => {
    const acc: T[] = []
    return {
      push: (x: T) => acc.push(x),
      drain: function* () {
        yield* acc
        acc.length = 0
      },
    }
  }
  ```

- Model resources as factory-returned `AsyncDisposable` records; capture state in the closure and teardown in `[Symbol.asyncDispose]`.

  ```typescript
  import { open } from "node:fs/promises"

  const readableFile = async (path: string): Promise<AsyncDisposable & { read: () => Promise<string> }> => {
    const file = await open(path, "r")

    return {
      read: () => file.readFile({ encoding: "utf8" }),
      [Symbol.asyncDispose]: async () => {
        await file.close()
      },
    }
  }
  ```

---

## Modern Builtins

- Use `using` / `await using` with `Symbol.dispose` / `Symbol.asyncDispose` instead of `try`/`finally` for cleanup.

- Collect async iterables with `Array.fromAsync()`.

- Use iterator helpers (`.map()`, `.filter()`, `.toArray()`) instead of spreading into arrays.

  - Enter iterator pipelines from arrays with `.values()`.

  - Compose generator pipelines directly: `f(g(h(xs.values())))`. Delegate inner iterables with `yield*`.

  - Call `.toArray()` only at a leaf that requires random access or multiple passes; use iterator helpers for scalar folds.

- Use `Set` methods: `.union()`, `.intersection()`, `.difference()`, `.symmetricDifference()`, `.isSubsetOf()`.

- Use `Promise.withResolvers()` instead of wrapping a constructor manually.

---

## Node Standard Library

- Prefer asynchronous APIs when synchronous and asynchronous variants both exist.

- Make `switch` exhaustive with `default: fail(value satisfies never)`; import `fail` from `node:assert/strict`.

- Use `node:*` imports instead of globals: `import { env, exit } from "node:process"`.

- Use `ok()` from `node:assert/strict` instead of `if`/`throw`.

- Convert a stream to a string with `text(stream)` from `node:stream/consumers`.

- Await stream completion with `finished(stream)` from `node:stream/promises`.

- Convert an event to a promise with `once(emitter, event)` from `node:events`.

- Convert an async iterable to a stream with `Readable.from(asyncIterable)`.
