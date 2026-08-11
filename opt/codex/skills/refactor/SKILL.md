---
name: refactor
description: Simplify code, contracts, and data flow through iterative refactoring.
---

Use @../op-topology-decomposition/SKILL.md.

---

# Refactor

## Observation

- Select one affected concern, contract, control flow, or data flow per pass.

- Identify the affected entry points, exits, and governing contracts.

- Record the current tests, types, effects, and topology.

## Abduction

_Devise a structural explanation and refactoring hypothesis._

- Hypothesize a topology change that explains the observed complexity and improves locality.

- Explore candidate changes, including:

  - Move or resize boundaries to de-complect responsibilities.

  - Divide the flow into stages with explicit contracts.

  - Lift branches toward entry points and push loops toward leaf operations.

## Deduction

_Derive consequences of the refactoring hypothesis._

- Derive observable consequences:

  - Affected contracts remain valid or have a locally verifiable delta.

  - Changed flows become more local and stages more explicit.

## Induction

_Test those consequences and provisionally retain or revise the hypothesis._

- Test the derived consequences with relevant tests, types, contract checks, and effect checks.

- Reject a refactor that leaves the next change less local or less verifiable.

- Use the observed result to retain, revise, or re-model the topology for the next pass.

- Surface a design or plan when broader judgment, migration, or coordination is required.
