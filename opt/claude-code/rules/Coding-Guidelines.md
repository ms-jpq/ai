# Coding Guidelines

## Design

- The system is a pipeline of stages (I → O). Decompose along stage boundaries.

- Plain data types instead of OOP.

- Immutable by default.

- Transforms or effects. Not both.

- Exhaustive matching over the state space.

- State materializes at stage boundaries only.

- Lazy over eager. Generators / iterators / streams.

- Generic interfaces over concrete types. When concrete, most specific.

- Stdlib over hand-rolled.

- If tests need mocks, the code is wrong.

## Workflow

- Start LSPs for the relevant languages before writing or changing code.
