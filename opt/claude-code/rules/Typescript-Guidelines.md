# TypeScript Guidelines

- `const foo = () => {}` over `function foo() {}`.

- `const foo = function*() {}` for generators. `IteratorObject<T>` for sync, `AsyncGenerator<T>` for async. Explicit `return` at the bottom of the body.

- Most generic type wins. `Map<K, V>` over `Record<K, V>` for runtime key-value stores. `Record` is fine in type positions for object shapes.

- Generators over eagerly-built arrays or stateful accumulators. Yield lazily; let the caller collect.

- IIFEs `(() => {})()` to localize or eliminate mutable state.

- Async over sync when both exist.

- `node:*` imports — e.g. `import { env, exit } from "node:process"` over `process.*` globals.

- `import type` for type-only imports, especially packages used only for their types.

- `ok()` from `node:assert/strict` over manual `if/throw` for invariant checks.

- Modern stdlib over hand-rolled equivalents:
  - `text(stream)` from `node:stream/consumers` to read a stream into a string.
  - `finished(stream)` from `node:stream/promises` to await stream completion.
  - `once(emitter, event)` from `node:events` for event-to-promise.
  - `Readable.from(asyncIterable)` to bridge async iterables into streams.
  - `Array.fromAsync(asyncIterable)` to collect async iterables.
