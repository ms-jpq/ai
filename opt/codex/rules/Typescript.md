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

- After the primary operand, pass arguments through one destructured parameters object. Inline its type unless shared.

  ```typescript
  const read = (path: string, { limit = 100 }: { limit?: number }) => {}
  ```

- Use generators to encapsulate incremental iteration state; define them with `const foo = function*() {}`.

  - Use `IteratorObject<T>` for synchronous generators and `AsyncIteratorObject<T>` for asynchronous generators.

  - Compose generator pipelines directly and delegate inner iterables with `yield*`.

  - End generator bodies with an explicit `return`.

  ```typescript
  const flatten = function* <T>(groups: Iterable<Iterable<T>>): IteratorObject<T> {
    for (const group of groups) {
      yield* group
    }
    return
  }
  ```

---

## Types

- Narrow unknown input at the boundary with control flow, not casts.

- Use `satisfies` to validate a shape without widening inferred literal types.

  ```typescript
  const status = {
    kind: "ready",
    retryable: false,
  } satisfies { kind: "ready" | "blocked"; retryable: boolean }
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

  ```typescript
  const limit = options.limit ?? 100
  ```

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

- Use iterator helpers instead of spreading into arrays.

  - Enter array pipelines with `.values()`.

  - Call `.toArray()` only at a leaf that requires random access or multiple passes.

  - Collect async iterables with `Array.fromAsync()`.

  ```typescript
  const names = items
    .values()
    .filter((item) => item.enabled)
    .map((item) => item.name)
    .toArray()
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
  import { mkdtemp, rm } from "node:fs/promises"
  import { tmpdir } from "node:os"
  import { join } from "node:path"

  const temporaryDirectory = async (): Promise<AsyncDisposable & { path: string }> => {
    const path = await mkdtemp(join(tmpdir(), "work-"))

    return {
      path,
      [Symbol.asyncDispose]: async () => {
        await rm(path, { recursive: true, force: true })
      },
    }
  }
  ```

---

## Concurrency

- Use structured concurrency: never let async work escape its owner scope.

- Start sibling work together, await it together, and thread through shared `AbortSignal`s.

  ```typescript
  const controller = new AbortController()
  const options = { signal: controller.signal }

  try {
    const [left, right] = await Promise.all([readLeft(options), readRight(options)])
  } finally {
    controller.abort()
  }
  ```

---

## NodeJS

- Prefer asynchronous APIs when synchronous and asynchronous variants both exist.

- Make `switch` exhaustive with `default: fail(value satisfies never)`; import `fail` from `node:assert/strict`.

  ```typescript
  switch (state) {
    case "ready":
      return start()
    case "done":
      return stop()
    default:
      return fail(state satisfies never)
  }
  ```

- Use `node:*` imports instead of globals: `import { env, exit } from "node:process"`.

- Use `ok()` from `node:assert/strict` instead of `if`/`throw` in tests.

- Convert a stream to a string with `text(stream)` from `node:stream/consumers`.

- Await stream completion with `finished(stream)` from `node:stream/promises`.

  ```typescript
  const body = await text(input)
  await finished(output)
  ```

- Convert events to promises with `once(emitter, event, { signal })`; abort sibling listeners in `finally`.

  ```typescript
  import { once } from "node:events"

  const controller = new AbortController()
  const options = { signal: controller.signal }

  try {
    await Promise.race([once(process, "SIGTERM", options), once(process, "SIGINT", options)])
  } finally {
    controller.abort()
  }
  ```
