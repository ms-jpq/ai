---
name: refactor
description: Simplify code, contracts, and data flow through iterative refactoring.
---

# Refactor

Use @../op-purpose-formation/SKILL.md to establish the preservation boundary and intended delta.

Use @../op-problem-framing/SKILL.md to frame the refactoring problems and prioritize their concerns.

Use @../op-topology-recomposition/SKILL.md to resolve the structural concerns in code.

Use @../op-conceptual-synthesis/SKILL.md to give parts, contracts, and flows consistent names.

Use @../op-mechanism-alignment/SKILL.md to preserve or revise the mechanisms that cover salient concerns.

## Observation

- Select one refactoring problem and its required behavioral preservation or intended delta.

- Identify the affected entry points, exits, and contracts.

- Establish a passing baseline with existing tests or new characterization tests.

  - Cover a normal case, a boundary case, and relevant failure behavior.

## Abduction

_Devise an explanation for observations._

- Propose a structural change that resolves the framed concern while preserving the baseline.

- State every intended behavioral or contract delta explicitly.

- Explore candidate changes, including:

  - Move or resize boundaries to de-complect responsibilities.

  - Divide the flow into stages with explicit contracts.

  - Lift branches toward entry points and push loops toward leaf operations.

## Deduction

_Derive consequences of the explanation._

- Derive executable claims:

  - Characterization tests remain valid except at each stated delta.

  - Each stated delta has a test that distinguishes it from a regression.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Add or update the tests derived above.

- Run the affected tests, types, contract checks, and effect checks.

- Reject a refactor when a preserved behavior changes or a stated delta lacks a discriminating test.

- Retain the refactor only when the tests pass and the next change is more local or verifiable.

- Surface a design or plan when broader judgment, migration, or coordination is required.
