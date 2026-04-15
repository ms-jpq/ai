# Coding Guidelines

- Start LSPs for the relevant languages before writing or changing code.

- Plain data over custom types.

- Immutable by default.

- Separate data from effects.

- Exhaustive matching over the state space.

- State materializes at data boundaries only.

- Lazy over eager. Generators / iterators / streams.

- Wide interfaces, narrow shapes.

- Stdlib over hand-rolled.

- If tests need mocks, the code is wrong.
