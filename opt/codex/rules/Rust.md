---
paths:
  - "*.rs"
---

# Rust

## Defaults

- Enable `#![deny(clippy::all, clippy::cargo, clippy::pedantic)]`.

---

## Generics

- Accept `impl Into<T>` when the function needs a `T`. Convert at the boundary.

  ```rust
  fn open(path: impl Into<PathBuf>) {
    let path: PathBuf = path.into();
    // ...
  }
  ```

---

## Dynamic Dispatch

- `dyn Trait` is _banned_. Use generics and static dispatch.

---

## Bindings

- Use block expressions to scope intermediate values when computing a binding.

- Use shadowing to refine a value after platform-specific conversion.

---

## Structured Concurrency

- Use structured concurrency: threads, async tasks, and child processes must finish before their owning scope returns.

- On failure or cancellation, stop sibling work and join or await it before leaving the scope.
