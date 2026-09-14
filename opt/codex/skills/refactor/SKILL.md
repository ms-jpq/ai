---
name: refactor
description: Simplify code, contracts, and data flow through iterative refactoring.
---

# Refactor

Use @../op-purpose-formation/SKILL.md to establish the refactor's:

- Preservation boundary: behavior, contracts, constraints, and meaning that must remain unchanged.

- Intended delta: behavior or contract changes explicitly included in the request or subsequently agreed with the user.

Use @../op-problem-framing/SKILL.md to frame the refactoring problems and prioritize their concerns.

Use @../op-topology-recomposition/SKILL.md to resolve the structural concerns in code.

Use @../op-conceptual-synthesis/SKILL.md to give parts, contracts, and flows consistent names.

Use @../op-mechanism-alignment/SKILL.md to preserve or revise the mechanisms that cover salient concerns.

Use @../active-review/SKILL.md throughout each pass to probe decisions and the adequacy of their evidence.

- Supply the refactor's goal, preservation boundary, intended delta, and current problem frame.

## Artifact (Output)

- A simpler affected system that preserves its stated boundary and realizes only the authorized delta.

- Passing tests and checks that distinguish the intended delta from regressions.

  - Evidence that subsequent changes are more local or verifiable.

## Observation (Input)

- Select one refactoring problem.

- State its preservation boundary and intended delta.

- Identify the affected entry points, exits, and contracts.

- Establish a passing baseline with existing tests or new characterization tests.

  - Cover a normal case, a boundary case, and relevant failure behavior.

## Abduction

_Devise an explanation for observations._

- Propose a structural change and explain how it removes the cause of the refactoring problem.

- Explore candidate changes, including:

  - Move or resize boundaries to de-complect responsibilities.

  - Divide the flow into stages with explicit contracts.

  - Lift branches toward callers that own the decision and push loops toward operations that own the collection, when this reduces cross-boundary dependencies.

## Deduction

_Derive consequences of the explanation._

- Derive expected results for affected entry points, including boundary and failure cases.

- Identify which baseline assertions remain applicable and which authorized deltas require different expected results.

- Derive a test that distinguishes each authorized delta from an unintended behavior change.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Implement the proposed structural change within the preservation boundary and intended delta.

- Add or update the tests derived above.

- Run the affected tests, types, contract checks, and effect checks.

- Compare results with the derived expectations and reject unexplained differences.

- Exercise a representative subsequent change to assess whether the new structure makes it more local or verifiable.

## Iteration

- Re-invoke `refactor` while review identifies further in-scope changes that could simplify the affected system without violating its preservation boundary.

- Stop after a pass identifies no further supported simplification. Report unresolved candidates and what prevents evaluating them.
