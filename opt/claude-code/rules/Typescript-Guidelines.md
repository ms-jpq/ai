# TypeScript Guidelines

- `const foo = () => {}` over `function foo() {}`.

- For generators, use `const foo = function*() {}`. Type the return as `IteratorObject<T>`, not `Generator<T>` — add an explicit `return` in the body to satisfy this.

- Prefer the most generic type. `Map<K, V>` over `Record<K, V>` for runtime key-value stores. `Record` is fine in type positions for object shapes.

- Prefer generators over eagerly-built arrays or stateful accumulators. Yield values lazily; let the caller decide when to collect.

- Use IIFEs `(() => {})()` to localize or eliminate mutable state.

- Prefer async over sync when both exist.

- Prefer modern stdlib APIs over hand-rolled equivalents: `Array.fromAsync`, `text(stream)` from `node:stream/consumers`, `finished(stream)` from `node:stream/promises`, etc.
