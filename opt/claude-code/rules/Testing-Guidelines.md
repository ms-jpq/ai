# Testing Guidelines

## Parallelism

- All unit tests run in parallel. No sequential test groups.

- Shuffle test execution order.

## Testability

- Tests call functions directly and assert on return values. No spawning child processes, capturing output streams, or parsing logs.
