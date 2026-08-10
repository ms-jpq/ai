---
name: refactor
description: Simplify code, contracts, and data flow through iterative refactoring.
---

Use @../op-topology-decomposition/SKILL.md.

---

# Refactor

## Isolate

- Select one concern, contract, control-flow or data-flow change per pass.

## Baseline

- Bound the domain as contracts and follow data from entry points to exit points.

- Record the current tests, types, effects, and topology.

## Refactor

- Move or resize boundaries to de-complect responsibilities.

- Preserve contracts by default; improve them only when locally verifiable.

- Divide the flow into stages with explicit contracts.

- Lift branches toward entry points and push loops toward leaf operations.

## Falsify

- Run relevant tests and check contracts, types, effects, and resulting data flow.

- Reject a refactor that leaves the next change less local or less verifiable.

## Revise

- Re-model the topology and apply the observed result to the next pass.

- Stop when the flow is laminar: direct, staged, and unsurprising.

- Surface a design or plan when evidence requires broader judgment, migration, or coordination.
