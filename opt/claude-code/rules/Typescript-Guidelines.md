# Typescript Guidelines

- `const foo = () => {}` over `function foo() {}`.

- For iterables, use `const foo = function*() {}`. Type as `IteratorObject<T>`, not `Generator<T>` — this requires an explicit `return` in the generator body.

- Prefer the most generic type. `Map<K, V>` over `Record<K, V>` for runtime key-value stores. `Record` is fine in type positions for object shapes.

- Use IIFEs `(() => {})()` to localize or eliminate mutable state.

- Prefer async over sync when both exist.
