---
paths:
  - "*.java"
  - "*.jsh"
---

# Java

## Bindings

- Prefer `final var` for local bindings.

---

## Collection Transforms

```java
final var combined =
    Stream.of(prefix.stream(), values.stream(), suffix.stream())
        .flatMap(stream -> stream)
        .toList();
```

- Compose `map`, `filter`, and `flatMap` instead of mutating an external accumulator.

- Use `Stream.concat` for two streams and `flatMap` for a sequence of streams.

- Prefer method references when a lambda only forwards its argument.

- Collect with `toList()` or `toArray(Type[]::new)` at the boundary that needs the collection.

---

## Structured Concurrency

- Join tasks and child processes before their owning scope returns.

- On failure or interruption, cancel sibling work and wait for cleanup before propagating the failure.

- Propagate `InterruptedException`, or restore the interrupt flag when translating it to another failure.
