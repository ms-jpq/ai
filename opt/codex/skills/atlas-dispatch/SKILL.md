---
name: atlas-dispatch
description: Spawn agents on unclaimed atlas nodes along the execution frontier and record their assignments.
---

# Atlas Dispatch

---

## Artifact (Output)

_State the intended properties declaratively._

- Selected, unclaimed frontier nodes have agents assigned to carry out their work.

- Each assignment includes the node's outcome, source context, boundaries, and acceptance checks.

- The atlas records node ownership and agent identity. Undispatched work remains identifiable.

---

## Observation (Input)

_State the input categories and their roles._

- Selected nodes and ordering edges define candidate work and its prerequisites.

- Completion evidence, ownership, and running agents establish readiness and existing assignments.

- Node descriptions and references supply each agent's brief.

- The domain and execution permissions bound assignments.

---

## Abduction

_Devise an explanation for observations._

- Propose concurrent assignments for unclaimed nodes whose ordering constraints are satisfied.

- Identify overlapping writes or shared resources that require coordination between assignments.

---

## Deduction

_Derive consequences of the explanation._

- Derive each agent's inputs, expected output, and ownership boundary from its node.

- Check that the assignments cover selected ready work without duplicating active assignments.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Recheck ownership and prerequisite evidence before dispatch.

- Spawn agents concurrently with their node briefs and record successful assignments in the atlas.

- Verify that each recorded assignment corresponds to a spawned agent. Leave failed dispatches unclaimed and record the cause.

- Report assignments and undispatched nodes. Completion requires returned work and acceptance evidence.
