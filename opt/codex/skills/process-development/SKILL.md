---
name: process-development
description: Maximize parallel progress by separating reusable stages from task-specific work.
---

# Process Development

## Goals

- Make the pipeline as wide as dependencies permit, preserving required outcomes without adding unnecessary coordination.

- Separate the common core from task-specific variations so independent work can proceed in parallel and rejoin only where its outcomes are needed.

- Use @../converge/SKILL.md when the process's purpose, concerns, outcome dependencies, or mechanisms need clarification.

## Artifact (Output)

- A reusable process specification separating shared stages from task-specific paths.

  - Applicable situations, required inputs, desired outcome, and constraints.

  - Intermediate outcomes with observable completion conditions and only the dependencies needed to achieve them.

  - Transformations defined by required inputs and resulting outcomes, with suggested methods distinguished from required steps.

  - Independent paths, necessary joins, and shared-resource constraints.

  - Explicit choices, branches, retries, and unresolved gaps where needed.

- Evidence of preserved outcomes and parallel progress, with untested paths and unresolved bottlenecks explicit.

## Observation (Input)

- Read representative tasks, their required outcomes, inputs, constraints, and existing procedures.

- Compare attempts to identify shared stages, task-specific variations, failures, and workarounds.

- Record where work waits, what releases it, and which dependencies or shared resources are claimed to require that order.

- Seek established processes for the same or analogous problems before inventing one.

## Abduction

_Devise an explanation for observations._

- Explain which waits arise from necessary dependencies and which arise from coupling unrelated work.

- Use @../op-topology-recomposition/SKILL.md to propose intermediate outcomes and dependencies that separate reusable stages from task-specific paths.

- Use @../op-mechanism-alignment/SKILL.md to propose how each transformation produces its outcomes, distinguishing required steps from replaceable methods.

- Keep variations separate without duplicating the core or forcing unrelated tasks through its exceptions. Use parameters where the transformation remains the same.

- Propose parallel paths that join only where their results are needed, retaining necessary sequencing and removing broad synchronization barriers.

## Deduction

_Derive consequences of the explanation._

- Trace common and variant cases through the proposed paths, checking that each join receives the outcomes its dependants require.

- Predict which waits disappear, which remain, and whether contention or coordination would erase the expected gain.

- Predict how a delayed, failed, or retried path affects the others and what permits recovery without blocking independent work.

- Identify observations that distinguish a missing dependency, an ineffective method, and execution that departs from the specification.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Run shared stages and representative variations together within the permitted scope, checking intermediate and final outcomes. Mark unexecuted paths as untested.

- Compare actual waiting and parallel progress with predictions, including interference, duplicated work, and coordination costs.

- Revise boundaries, dependencies, or methods where the comparison exposes a defect. Correct execution errors without automatically changing the specification.

- Test revisions against previously supported cases to distinguish a reusable improvement from a case-specific workaround.

- Remove stages, steps, or barriers shown unnecessary for required outcomes. Retain parallelism only when it improves progress without violating constraints.

## Iteration

- Re-invoke `process-development` when use exposes avoidable waiting, a failure, or a variation the shared process handles poorly.

- Update the reusable specification so later executions benefit from the revision.
