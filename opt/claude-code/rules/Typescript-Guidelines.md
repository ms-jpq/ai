# Typescript Guidelines

## Style

1. Prefer `() =>` arrow functions.

2. Use generator `function*` for writing iterables.

3. Use the most generic type. for example: use `IteratorObject<T>` rather than `Generator<T>`

4. When there is both a sync and async version of doing something, prefer async.
