---
name: sop
description: Build or revise a standard operating procedure, or advance it through one verified principal state transition.
---

# SOP

## Artifact (Output)

_State the intended properties declaratively._

- **Procedure:** Principal states and transitions connecting starting conditions to the desired outcome.

- **Transition record:** The starting state, action taken, and resulting state.

---

## Observation (Input)

_State the input categories and their roles._

- **Purpose and constraints:** What the process must achieve and preserve.

- **Current state:** Starting conditions and completed steps.

- **Procedure:** Existing states, transitions, and completion conditions, if defined.

- **Cases:** Tasks and execution history showing recurring work, variations, and bottlenecks.

---

## Abduction

_Devise an explanation for observations._

- When building or revising, propose observable principal states and transitions connecting the starting conditions to the desired outcome.

  - Specify each transition's prerequisites, actions, and completion conditions.

  - Extract shared stages from representative cases, parameterizing differences and separating task-specific work.

  - Allow independent stages to proceed concurrently, with joins waiting for their required outcomes.

- When advancing, assess the current state against the procedure's observable conditions, then propose the next transition whose prerequisites are satisfied.

  - Keep uncertain state assignments explicit.

---

## Deduction

_Derive consequences of the explanation._

- Trace representative cases through the proposed procedure.

  - Identify unreachable outcomes, missing prerequisites, and branches without a continuation or stopping condition.

  - Predict how delays, failures, and retries affect dependent and independent work.

- Predict each proposed transition's effects and derive checks that distinguish completion from an attempt.

  - Identify conditions that would prevent completion.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- When building or revising, represent the procedure in tables.

  - Test revisions against existing cases and new variations, checking for duplication, unnecessary waiting, and task-specific exceptions in shared stages.

  - Mark untested transitions explicitly.

- When advancing, perform the transition within the authorized scope, stopping at the next principal state.

  - Check the resulting state against the predicted completion conditions before recording advancement.

  - If blocked or already complete, record why no transition was taken.

---

- Use @../op-topology-recomposition/SKILL.md when intermediate outcomes and dependencies need organizing into steps.

- Use @../op-mechanism-alignment/SKILL.md to select actions that produce the required outcomes.

- Use @../mat/SKILL.md to represent principal states and transitions in tables.
