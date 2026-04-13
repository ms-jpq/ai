# Testing Guidelines

## Parallelism

- All unit tests run in parallel. No sequential test groups.

- Shuffle test execution order.

## Testability

- Functions that do IO return data or yield values — never write to stdout, stderr, or files directly.

- Tests call functions directly and assert on return values. No spawning child processes, capturing output streams, or parsing logs.

- No mocking, stubbing, or patching. If something is hard to test without mocks, refactor the code.
