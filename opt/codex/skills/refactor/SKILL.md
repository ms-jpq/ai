---
name: refactor
description: Discover and remove unnecessary complexity, implementing and testing simpler alternatives while preserving required behaviour and meaning.
---

# Refactor

## Artifact (Output)

_State the intended properties declaratively._

- **System:** Less unnecessary complexity, with required behaviour and meaning preserved except for agreed changes.

---

## Observation (Input)

_State the input categories and their roles._

- **System:** The current structure, its purpose, and observed friction.

- **Constraints:** Required behaviour, contracts, meaning, and rules, including agreed changes.

- **Checks:** Tests and observations establishing the behaviour to preserve.

---

## Abduction

_Devise an explanation for observations._

- Select one supported simplification opportunity per pass.

  - Inspect entry points, dependencies, branches, repeated transformations, and exceptions.

  - Distinguish requirements and dependent consumers from incidental structure.

- Ask what could disappear while the requirements still hold.

  - Identify the assumption that makes each candidate necessary before proposing its removal.

- Propose removal, consolidation, replacement, or restructuring, and explain why the simpler alternative still satisfies the requirements.

---

## Deduction

_Derive consequences of the explanation._

- Derive expected results for affected entry points, including boundary and failure cases.

- Identify which baseline assertions remain applicable and justify changed expectations from requirements.

- Derive tests that would expose a missing responsibility or regression if the proposed removal or replacement were wrong.

- Predict what dependencies, exceptions, coordination, or required context the alternative removes, and what complexity it introduces elsewhere.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Establish a passing baseline with existing tests or new characterization tests before changing the implementation.

  - Cover a normal case, a boundary case, and relevant failure behaviour.

  - Distinguish assertions of required behaviour from assertions that merely mirror the current implementation.

- Implement the alternative and run the derived tests, affected existing tests, and applicable static and contract checks.

  - Compare results with the derived expectations and reject unexplained differences.

- Reject reductions that merely relocate complexity to callers, configuration, instructions, or operational work.

- If the alternative promises to make future changes easier to isolate or verify, try a representative change.

- Retain demonstrated simplifications and remove superseded material.

- Repeat after each retained change until a pass finds no further supported simplification.

  - Report unresolved candidates and what prevents evaluating them.

---

- Use @../adversarial-questions/SKILL.md throughout each pass to derive questions from the refactor's purpose and concerns.

- Use @../converge/SKILL.md when review requires revising the system purpose, problem frame, or design model.

- Use @../op-topology-recomposition/SKILL.md during abduction to propose simpler components, boundaries, and connections.

- Use @../op-mechanism-alignment/SKILL.md during abduction to propose shared mechanisms in place of special cases while preserving required effects.

- Use @../op-conceptual-synthesis/SKILL.md during abduction when inconsistent names or obscured distinctions complicate the system.
