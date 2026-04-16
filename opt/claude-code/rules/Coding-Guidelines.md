# Coding Guidelines

## Macro

- Model the system as a series of stages (I → O). Decompose along stage boundaries.

- Types model the domain. Each stage has a single types file, complete enough to describe the problem.

- Records over classes.

- Transforms or effects. Not both.

- Persistent state lives at stage boundaries — files, queues, databases.

- Every component testable by direct call and return value.

- Generic interfaces at stage boundaries. Concrete (most specific) within a stage.

## Micro

- Frozen data by default. Mutation requires justification.

- Exhaustive matching over the state space.

- Lazy over eager; generators and streams over collections.

## Workflow

- Start LSPs for the relevant languages before writing or changing code.
