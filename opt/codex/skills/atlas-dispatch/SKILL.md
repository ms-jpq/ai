---
name: atlas-dispatch
description: Spawn agents on unclaimed atlas nodes along the execution frontier and record their assignments.
---

# Atlas Dispatch

---

## Artifact (Output)

_State the intended properties declaratively._

- **Assignments:** Selected frontier nodes claimed by agents, with ownership and agent identity recorded in the atlas.

---

## Observation (Input)

_State the input categories and their roles._

- **Selection:** Nodes to dispatch and their ordering dependencies.

- **Execution state:** Completion evidence, ownership, and running agents that establish readiness and existing assignments.

- **Context:** Node descriptions and references that supply each agent's brief.

- **Authority:** Domain and execution permissions that bound assignments.

---

## Abduction

_Devise an explanation for observations._

- Propose concurrent assignments for unclaimed nodes whose ordering constraints are satisfied.

- Identify overlapping writes or shared resources that require coordination between assignments.

---

## Deduction

_Derive consequences of the explanation._

- Derive each agent's inputs, expected output, and ownership boundary from its node.

  - Include source context and acceptance checks in its brief.

- Check that the assignments cover selected ready work without duplicating active assignments.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Recheck ownership and prerequisite evidence before dispatch.

- Spawn agents concurrently with their node briefs and record successful assignments in the atlas.

- Verify that each recorded assignment corresponds to a spawned agent. Leave failed dispatches unclaimed and record the cause.
