# TypeScript Guidelines

- `const foo = () => {}` over `function foo() {}`.

- For generators, use `const foo = function*() {}`. Type sync generators as `IteratorObject<T>`, async generators as `AsyncGenerator<T>`. Add an explicit `return` at the bottom of the body.

- Prefer the most generic type. `Map<K, V>` over `Record<K, V>` for runtime key-value stores. `Record` is fine in type positions for object shapes.

- Prefer generators over eagerly-built arrays or stateful accumulators. Yield lazily; let the caller collect.

- Use IIFEs `(() => {})()` to localize or eliminate mutable state.

- Prefer async over sync when both exist.

- ESM imports from `node:*` — e.g. `import { env, exit } from "node:process"` over `process.*` globals.

- `import type` for type-only imports, especially packages used only for their types.

- `ok()` from `node:assert/strict` for invariant checks over manual `if/throw`.

- Prefer modern stdlib APIs over hand-rolled equivalents:
  - `text(stream)` from `node:stream/consumers` to read a stream into a string.
  - `finished(stream)` from `node:stream/promises` to await stream completion.
  - `once(emitter, event)` from `node:events` for event-to-promise.
  - `Readable.from(asyncIterable)` to bridge async iterables into streams.
  - `Array.fromAsync(asyncIterable)` to collect async iterables.
