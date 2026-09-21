---
name: refactor
description: Discover and remove unnecessary complexity, implementing and testing simpler alternatives while preserving required behaviour and meaning.
---

# Refactor

- Use @../adversarial-questions/SKILL.md throughout each pass to derive questions from the refactor's purpose and concerns, answering them through the comparisons and tests below.

- Use @../converge/SKILL.md when review requires revising the system purpose, problem frame, or design model.

## Artifact (Output)

- A simpler affected system, with changes implemented and required behaviour, contracts, constraints, and meaning preserved.

- Passing tests and checks that distinguish agreed changes from regressions.

- Evidence of reduced complexity or more local, verifiable subsequent changes.

## Observation (Input)

- Read the system purpose, current work, applicable rules, and observed friction.

- State the preservation boundary: behaviour, contracts, constraints, and meaning that must remain unchanged.

  - Separate these requirements from incidental structure.

  - Record behaviour or contract changes explicitly requested or subsequently agreed with the user.

- Inspect entry points, dependencies, branches, repeated transformations, and exceptions for complexity whose necessity is unclear.

- Identify the requirement each candidate serves and the consumers that depend on it.

- Select one supported simplification opportunity per pass.

- Establish a passing baseline with existing tests or new characterization tests.

  - Cover a normal case, a boundary case, and relevant failure behaviour.

  - Distinguish assertions of required behaviour from assertions that merely mirror the current implementation.

## Abduction

_Devise an explanation for observations._

- Ask what could disappear while the requirements still hold.

  - Identify the assumption that makes each candidate necessary before proposing its removal.

- Use @../op-topology-recomposition/SKILL.md to simplify outcome dependencies, boundaries, and flows.

- Use @../op-mechanism-alignment/SKILL.md to replace special cases with shared mechanisms, existing or proposed, while preserving required effects.

- Use @../op-conceptual-synthesis/SKILL.md when inconsistent names or obscured distinctions complicate the system.

- Propose removal, consolidation, replacement, or restructuring, and explain why the simpler alternative still satisfies the requirements.

- Consider leaving the current design unchanged.

  - Fewer lines alone do not establish lower complexity.

## Deduction

_Derive consequences of the explanation._

- Derive expected results for affected entry points, including boundary and failure cases.

- Identify which baseline assertions remain applicable and justify changed expectations from requirements, not from the proposed implementation.

- Derive tests that would expose a missing responsibility or regression if the proposed removal or replacement were wrong.

- Predict what dependencies, exceptions, coordination, or required context the alternative removes, and what complexity it introduces elsewhere.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Implement and test the alternative within the preservation boundary and agreed changes.

  - Keep the previous state recoverable for comparison.

- Run the affected tests, adding or updating those derived above, alongside applicable static and contract checks.

- Compare results with the derived expectations and reject unexplained differences.

- Reject reductions that merely relocate complexity across callers, configuration, instructions, or operational work when comparing the affected system.

- When the claimed benefit is more local or verifiable subsequent changes, test that claim with a representative change.

- Retain demonstrated simplifications and remove superseded material.

- Ask the user only when progress requires an unresolved product choice or a change beyond the agreed scope.

- Re-invoke `refactor` for another pass after each retained change to search for further simplifications.

- Stop after a pass identifies no further supported simplification.

  - Report unresolved candidates and what prevents evaluating them.
