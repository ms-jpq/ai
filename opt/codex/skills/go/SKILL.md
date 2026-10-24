---
name: go
description: Maximise parallelism through task decomposition and delegation.
---

# Go

- Use @../op-topology-recomposition/SKILL.md during abduction to organise intermediate outcomes into independent subtasks and distinguish necessary dependencies from incidental sequencing.

- See: `go func()`.

---

## Artifact (Output)

- Integrated results that satisfy the task, with unresolved work explicit.

---

## Observation (Input)

- Read the task, required outcomes, available inputs, and constraints.

- Identify dependencies and shared resources that could couple otherwise independent work.

---

## Abduction

_Devise an explanation for observations._

- Propose a decomposition into independently executable subtasks wherever possible.

  - Optimise task boundaries and dependencies for parallelism, disregarding capacity constraints during decomposition.

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
