# Testing

## Parallelism

- All unit tests run in parallel. Each test independent.

- Shuffle test execution order.

## Testability

- Tests call functions directly and assert on return values. Stay in-process — return values and exceptions are the test surface.
