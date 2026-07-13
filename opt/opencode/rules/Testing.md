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

---

## Declarative Cases

- Prefer declarative cases when one runner can exercise many examples:

  ```text
  input | actual | expected
  ```

- Keep case tables to data. Put setup, parsing, execution, normalization, and comparison in the runner.

- On failure, print the case name and all columns.

- Add imperative tests only for behaviour that the table cannot state clearly.
