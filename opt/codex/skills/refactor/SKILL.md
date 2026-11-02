---
name: refactor
description: Discover and remove unnecessary complexity, implementing and testing simpler alternatives while preserving required behaviour and meaning.
---

# Refactor

- Use @../adversarial-questions/SKILL.md throughout each pass to derive questions from the refactor's purpose and concerns.

- Use @../converge/SKILL.md when review requires revising the system purpose, problem frame, or design model.

- Use @../op-topology-recomposition/SKILL.md during abduction to propose simpler outcome dependencies, boundaries, and flows.

- Use @../op-mechanism-alignment/SKILL.md during abduction to propose shared mechanisms in place of special cases while preserving required effects.

- Use @../op-conceptual-synthesis/SKILL.md during abduction when inconsistent names or obscured distinctions complicate the system.

---

## Artifact (Output)

_State the intended properties declaratively._

- The affected system has less unnecessary complexity, with required behaviour, contracts, constraints, and meaning preserved except for agreed changes.

  - Evidence shows reduced complexity or more local, verifiable subsequent changes.

  - Simplification does not merely transfer complexity to callers, configuration, instructions, or operational work.

- Passing tests and checks that distinguish agreed changes from regressions.

---

## Observation (Input)

_State the input categories and their roles._

- System purpose, current implementation, and observed friction: context for finding unnecessary complexity.

- Required behaviour, contracts, constraints, meaning, and applicable rules: the preservation boundary.

  - Explicitly requested or subsequently agreed changes define exceptions to that boundary.

- Existing tests, checks, and observed results: evidence of current behaviour and a basis for comparison.

---

## Abduction

_Devise an explanation for observations._

- Inspect entry points, dependencies, branches, repeated transformations, and exceptions. Select one supported simplification opportunity per pass.

  - Distinguish requirements and dependent consumers from incidental structure.

- Ask what could disappear while the requirements still hold.

  - Identify the assumption that makes each candidate necessary before proposing its removal.

- Propose removal, consolidation, replacement, or restructuring, and explain why the simpler alternative still satisfies the requirements.

- Consider leaving the current design unchanged.

  - Fewer lines alone do not establish lower complexity.

---

## Deduction

_Derive consequences of the explanation._

- Derive expected results for affected entry points, including boundary and failure cases.

- Identify which baseline assertions remain applicable and justify changed expectations from requirements, not from the proposed implementation.

- Derive tests that would expose a missing responsibility or regression if the proposed removal or replacement were wrong.

- Predict what dependencies, exceptions, coordination, or required context the alternative removes, and what complexity it introduces elsewhere.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Establish a passing baseline with existing tests or new characterization tests before changing the implementation.

  - Cover a normal case, a boundary case, and relevant failure behaviour.

  - Distinguish assertions of required behaviour from assertions that merely mirror the current implementation.

- Implement and test the alternative within the preservation boundary and agreed changes.

  - Keep the previous state recoverable for comparison.

- Run the affected tests, adding or updating those derived above, alongside applicable static and contract checks.

  - Compare results with the derived expectations and reject unexplained differences.

- Reject reductions that merely relocate complexity to callers, configuration, instructions, or operational work.

- When the claimed benefit is more local or verifiable subsequent changes, test that claim with a representative change.

- Retain demonstrated simplifications and remove superseded material.

- Ask the user only when progress requires an unresolved product choice or a change beyond the agreed scope.

- Repeat after each retained change until a pass finds no further supported simplification.

  - Report unresolved candidates and what prevents evaluating them.
