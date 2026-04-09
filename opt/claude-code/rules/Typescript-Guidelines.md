# Typescript Guidelines

1. Prefer `const = () => {}` functions declarations.

2. Use generator `function*` for writing iterables, and use the `const = function*() {}` style of declarations.

3. Use the most generic type. for example: use `IteratorObject<T>` rather than `Generator<T>`.

4. Use `Map<K ,V>` instead of `Record<K, V>` to represent maps.

5. Use IIFE `(() => {})` to either localize or avoid mutable state.

6. When there is both a sync and async version of doing something, prefer async.
