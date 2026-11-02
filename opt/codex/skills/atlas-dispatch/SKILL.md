---
name: atlas-dispatch
description: Spawn agents on unclaimed atlas nodes along the execution frontier and record their assignments.
---

# Atlas Dispatch

## Artifact (Output)

_State the intended properties declaratively._

- **Assignments:** Selected frontier nodes claimed by agents, with ownership and agent identity recorded in the atlas.

---

## Observation (Input)

_State the input categories and their roles._

- **Execution frontier:** The view selecting work for dispatch.

- **Execution state:** Completed work, ownership, and running agents.

- **Context:** Node descriptions and references that supply each agent's brief.

- **Domain:** Nodes we may claim or update.

- **Permissions:** Actions the dispatched agents may perform.

---

## Abduction

_Devise an explanation for observations._

- Propose concurrent assignments for unclaimed frontier nodes.

- Identify overlapping writes or shared resources that require coordination between assignments.

---

## Deduction

_Derive consequences of the explanation._

- Derive each agent's inputs, expected output, and ownership boundary from its node.

  - Include source context and acceptance checks in its brief.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Recheck ownership and prerequisite completion before dispatch.

- Spawn agents concurrently with their node briefs and record successful assignments in the atlas.

- Leave failed dispatches unclaimed and record the cause.
