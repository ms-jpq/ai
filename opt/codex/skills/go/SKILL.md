---
name: go
description: Maximize parallelism through task decomposition and delegation.
---

# Go

- Use @../op-topology-recomposition/SKILL.md during abduction to organize intermediate outcomes into independent subtasks and distinguish necessary dependencies from incidental sequencing.

- See: `go func()`.

---

## Artifact (Output)

_State the intended properties declaratively._

- Integrated subtask outputs satisfy the task without conflicting changes.

  - Unresolved work remains explicit.

---

## Observation (Input)

_State the input categories and their roles._

- The task and required outcomes define what the combined work must achieve.

- Available inputs support execution, while constraints, known dependencies, and shared resources bound independence.

---

## Abduction

_Devise an explanation for observations._

- Propose a decomposition into independently executable subtasks.

  - Optimize task boundaries and dependencies for parallelism, disregarding capacity constraints during decomposition.

  - Define each subtask's inputs, output, and ownership boundary.

---

## Deduction

_Derive consequences of the explanation._

- Trace how subtask outputs combine to satisfy the required outcomes.

- Check which subtasks can run concurrently, which must wait for inputs, and where concurrent changes could conflict.

- Derive checks for each result and their integration.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Delegate independent subtasks concurrently, releasing dependent work as its inputs become available.

  - Limit waiting to required inputs and shared-resource constraints.

- Check returned results and integrate them against the required outcomes.

- Revise task boundaries or dependencies when execution exposes avoidable waiting, conflicting changes, or missing work.
