---
name: sop
description: Build or revise a standard operating procedure, or advance it through one verified principal state transition.
---

# SOP

- Distinguish requests to build or revise the procedure from requests to advance the process.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Procedure:** Principal states and transitions connecting starting conditions to the desired outcome.

- **Transition record:** The observed state, action taken, and completion evidence when advancing the process.

---

## Observation (Input)

_State the input categories and their roles._

- **Purpose and constraints:** What the process must achieve and preserve.

- **Current state:** Starting conditions and evidence of progress.

- **Procedure:** Existing states, transitions, and completion conditions, if defined.

---

## Abduction

_Devise an explanation for observations._

- When building or revising, propose observable principal states and transitions connecting the starting conditions to the desired outcome.

  - Specify each transition's prerequisites, actions, and completion conditions.

- When advancing, assess the current state against the procedure's observable conditions, then propose the next transition whose prerequisites are satisfied.

  - Keep uncertain state assignments explicit.

---

## Deduction

_Derive consequences of the explanation._

- Trace representative cases through the proposed procedure.

  - Identify unreachable outcomes, missing prerequisites, and branches without a continuation or stopping condition.

- Predict each proposed transition's effects and derive checks that distinguish completion from an attempt.

  - Identify conditions that would prevent completion.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- When building or revising, represent the procedure in tables.

  - Check it against representative cases and available execution evidence.

  - Mark untested transitions explicitly.

- When advancing, perform the transition within the authorized scope, stopping at the next principal state.

  - Check the resulting state against the predicted completion conditions before recording advancement.

  - Record the observed state and transition outcome.

  - If blocked or already complete, record why no transition was taken.

---

- Use @../op-topology-recomposition/SKILL.md when intermediate outcomes and dependencies need organizing into steps.

- Use @../op-mechanism-alignment/SKILL.md to select actions that produce the required outcomes.

- Use @../process-development/SKILL.md to extract a reusable procedure from several tasks.

- Use @../mat/SKILL.md to represent principal states and transitions in tables.
