---
name: go
description: Maximize parallelism through task decomposition and delegation.
---

# Go

- See: `go func()`.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Result:** Integrated subtask outputs that satisfy the task.

---

## Observation (Input)

_State the input categories and their roles._

- **Task:** The work to complete and its required outcomes.

- **Resources:** Inputs and shared resources available for execution.

- **Constraints:** Dependencies and limits on how the work can proceed.

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

- Check returned results and integrate them against the required outcomes.

- Revise task boundaries or dependencies when execution exposes avoidable waiting, conflicting changes, or missing work.

---

- Use @../op-topology-recomposition/SKILL.md during abduction to organize intermediate outcomes into independent subtasks and distinguish necessary dependencies from incidental sequencing.
