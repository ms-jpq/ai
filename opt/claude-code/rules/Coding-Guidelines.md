# Coding Guidelines

## Design

- Model the system as a series of stages (I → O). Decompose along stage boundaries.

- Types model the domain. For every stage, a single file of types reads as the problem statement.

- Records types over OOP.

- Frozen data by default. Mutation requires justification.

- Transforms or effects. Not both.

- State materializes at stage boundaries only.

- Lazy over eager. Generators / iterators / streams.

- Generic interfaces over concrete types. When concrete, most specific.

- If tests need mocks, the code is wrong.

## Implementation

- Expression over statement.

- Exhaustive matching over the state space.

## Workflow

- Start LSPs for the relevant languages before writing or changing code.
