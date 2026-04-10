# Typescript Guidelines

1. Prefer `const foo = () => {}` over `function foo() {}` for function declarations.

2. Use generator `function*` for writing iterables, and use the `const foo = function*() {}` style of declarations.

3. Use the most generic type. For example: use `IteratorObject<T>` rather than `Generator<T>`.

4. Use `Map<K, V>` instead of `Record<K, V>` for runtime key-value stores. `Record` is still appropriate for typing object shapes in type positions.

5. Use IIFEs `(() => {})()` to either localize or avoid mutable state.

6. When there is both a sync and async version of doing something, prefer async.
