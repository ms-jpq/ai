---
paths:
  - "*.rs"
---

# Rust

## Generics

- Accept `impl Into<T>` when the function needs a `T`. Convert at the boundary.

  ```rust
  fn open(path: impl Into<PathBuf>) {
    let path: PathBuf = path.into();
    // ...
  }
  ```

## Dynamic Dispatch

- `dyn Trait` is _banned_. Use generics and static dispatch.
