---
paths:
  - "*.test.*"
  - "*_test.*"
---

# Testing

## Parallelism

- Run all unit tests in parallel; keep each test independent.

- Shuffle test execution order.

---

## Testability

- Test transforms in-process through direct calls, return values, and exceptions.

- Test effects through substitutable boundary implementations.
