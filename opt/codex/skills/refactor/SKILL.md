---
name: refactor
description: Simplify code, contracts, and data flow through iterative refactoring.
---

Use @../op-topology-decomposition/SKILL.md.

---

# Refactor

## Observation

- Select one concern, contract, control-flow or data-flow change per pass.

- Bound the domain as contracts and follow data from entry points to exit points.

- Record the current tests, types, effects, and topology.

## Abduction

_Devise a structural explanation and refactoring hypothesis._

- Move or resize boundaries to de-complect responsibilities.

- Preserve contracts by default; improve them only when locally verifiable.

- Divide the flow into stages with explicit contracts.

- Lift branches toward entry points and push loops toward leaf operations.

## Deduction

_Derive consequences of the refactoring hypothesis._

- State the expected effect on locality, contracts, verification, and resulting data flow.

## Induction

_Test those consequences and provisionally retain or revise the hypothesis._

- Run relevant tests and check contracts, types, effects, and resulting data flow.

- Reject a refactor that leaves the next change less local or less verifiable.

- Re-model the topology and apply the observed result to the next pass.

- Stop when the flow is laminar: direct, staged, and unsurprising.

- Surface a design or plan when evidence requires broader judgment, migration, or coordination.
