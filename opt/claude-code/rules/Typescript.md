---
paths:
  - "**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs}"
---

# TypeScript

- `const foo = () => {}` over `function foo() {}`.

- `const foo = function*() {}` for generators. Must use `IteratorObject<T>` for sync, `AsyncIteratorObject<T>` for async.
  - Explicit `return` at body end.

- `({ ... })` — single params object for multi-argument functions. Inline the type unless shared.

```typescript
const fetch = ({
  url,
  timeout = 30,
  retries = 3,
}: {
  url: string
  timeout?: number
  retries?: number
}) => {}
```

- `satisfies` over type annotations where possible. Preserves literal/narrowed types.

- IIFEs `(() => {})()` to localize or eliminate mutable state.

- Closures over classes for stateful objects:

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

- Resources as factory-returned `AsyncDisposable` records — state captured in the closure, teardown in `[Symbol.asyncDispose]`.

- `unique symbol` keys for metadata attached to domain types.

```typescript
const META: unique symbol = Symbol("meta")
type Decorated = Base & { [META]: Meta }
```

- `undefined` over `null`. Never `T | null | undefined` — pick one, and it's `undefined`.

- `??` over `||` for nullish coalescing. `||` only for boolean short-circuit.

- No `as` casts except `as const`. Perform type narrowing instead.

- Only annotate types where not inferable. Do keep annotations on function signatures.

- `const` over `let`. Restructure with ternary destructuring, `.entries()`, or intermediate expressions to avoid mutation.

- `import type` for type-only imports.

- Modern builtins:
  - `using` / `Symbol.dispose` over `try/finally` for cleanup.
  - `Array.fromAsync()` to collect async iterables.
  - Iterator helpers (`.map()`, `.filter()`, `.toArray()`, etc.) over spreading into arrays.
    - Arrays enter via `.values()`.
    - `function*` pipelines compose by direct chaining — `f(g(h(xs.values())))`. `yield*` to delegate inner iterables.
    - `.toArray()` only at the leaf — random access, multiple passes, or scalar fold.
  - `Set` methods: `.union()`, `.intersection()`, `.difference()`, `.symmetricDifference()`, `.isSubsetOf()`.
  - `Object.groupBy()` / `Map.groupBy()` over manual reduce.
  - `Promise.withResolvers()` over manual constructor wrapping.

- Node stdlib:
  - Async over sync when both exist.
  - Exhaustive `switch` via `default: fail(value satisfies never)` — `fail` from `node:assert/strict`.
  - `node:*` imports — `import { env, exit } from "node:process"` over `process.*` globals.
  - `ok()` from `node:assert/strict` over `if/throw`.
  - `text(stream)` from `node:stream/consumers` — stream to string.
  - `finished(stream)` from `node:stream/promises` — await stream end.
  - `once(emitter, event)` from `node:events` — event to promise.
  - `Readable.from(asyncIterable)` — async iterable to stream.
