---
paths:
  - "*.go"
---

# Go

## Composition and Generics

```go
func sortedKeys[K cmp.Ordered, V any](entries map[K]V) []K {
	return slices.Sorted(maps.Keys(entries))
}
```

- Compose functions that take and return values.

- Separate I/O and concurrency from value transformations.

- Make reusable transforms generic, with only the constraints their operations require.

---

## Collections and Iterators

```go
func indexed[T any](values []T) map[int]T {
	return maps.Collect(slices.All(values))
}

func nonempty(values []string) []string {
	return slices.DeleteFunc(slices.Clone(values), func(value string) bool {
		return value == ""
	})
}
```

- Prefer standard `slices` and `maps` helpers to handwritten collection loops.

- Accept and return `iter.Seq[T]` or `iter.Seq2[K, V]` for lazy transforms.

- Collect iterators with `slices.Collect`, `slices.Sorted`, or `maps.Collect` only when a consumer needs a slice or map.

- Write custom adapters only for operations the standard library lacks.

- In custom iterators, return as soon as `yield` returns false.

- With `iter.Pull` or `iter.Pull2`, defer `stop()`.

---

## Structured Concurrency

- Join goroutines and child processes before their owning scope returns.

- Give sibling work a shared cancellation context owned by the caller.

- On failure, cancel siblings and join them before returning the error; `sync.WaitGroup` only handles joining.

- Make blocking operations respond to cancellation, including channel sends and receives.

- `exec.CommandContext` cancels the direct child; handle descendant processes explicitly.
