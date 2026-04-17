# TypeScript

- `const foo = () => {}` over `function foo() {}`.

- `const foo = function*() {}` for generators. `IteratorObject<T>` sync, `AsyncGenerator<T>` async. Explicit `return` at body end.

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

- Async over sync when both exist.

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
  - `Set` methods: `.union()`, `.intersection()`, `.difference()`, `.symmetricDifference()`, `.isSubsetOf()`.
  - `Object.groupBy()` / `Map.groupBy()` over manual reduce.
  - `Promise.withResolvers()` over manual constructor wrapping.

- Node stdlib:
  - `node:*` imports — `import { env, exit } from "node:process"` over `process.*` globals.
  - `ok()` from `node:assert/strict` over `if/throw`.
  - `text(stream)` from `node:stream/consumers` — stream to string.
  - `finished(stream)` from `node:stream/promises` — await stream end.
  - `once(emitter, event)` from `node:events` — event to promise.
  - `Readable.from(asyncIterable)` — async iterable to stream.
