---
name: converge
description: Converge on a non-trivial task by observing evidence, explaining it, deriving consequences, testing them, and revising the system model. Use to choose, sequence, and revisit convergence operators.
---

# Converge

## Loop

- Start from available evidence, then converge through `abduce → deduce → test → induce`.

  - **Abduce** a possible explanation or configuration that accounts for the evidence.

  - **Deduce** the observable consequences that would follow if the hypothesis were right.

  - **Test** those consequences through implementation, experiment, or feedback that could conflict with them.

  - **Induce** a provisional judgment from the result, then update the model, constraints, or next transformation.

## Constraints

- Formulate the problem before abduction.

- Generate competing hypotheses before selecting one.

- Design each test to distinguish the hypothesis from its alternatives.

- Treat a failed test as evidence against the hypothesis, its auxiliary assumptions, or the test mechanism until the fault is localized.

- Do not treat induction as proof; retain, reject, rank, or update a hypothesis provisionally.

- When external testing is weak, check coherence among relevant cases, principles, constraints, and the wider model.

## Operators

- Treat the model `S` of the system to affect as the shared state.

- Apply and re-enter these transformations in order as evidence warrants:

  1. **Situation modeling** makes the current decision situation explicit.

     - @../op-situation-modeling/SKILL.md

  2. **Topology decomposition** exposes and reshapes the model's structure.

     - @../op-topology-decomposition/SKILL.md

  3. **Horizon exploration** generates alternatives by varying assumptions, constraints, and framing.

     - @../op-horizon-exploration/SKILL.md

  4. **Conceptual synthesis** turns useful distinctions into reusable concepts.

     - @../op-conceptual-synthesis/SKILL.md

## Method

- Let a concrete method realize the selected operator.

- Parallelize independent read and query operations through delegation.
