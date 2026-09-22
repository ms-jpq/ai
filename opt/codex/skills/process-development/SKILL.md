---
name: process-development
description: Extract reusable stages from varied tasks and organize them into efficient pipelines.
---

# Process Development

## Goals

- Discover the common process within varied tasks rather than treating each task as a separate procedure.

- Make the pipeline as wide as dependencies permit while preserving required outcomes and avoiding unnecessary coordination.

- Keep the common core and residual task-specific work disjoint, joining their outcomes only where needed.

- Use @../converge/SKILL.md when the process's purpose, concerns, outcome dependencies, or mechanisms need clarification.

## Artifact (Output)

- A reusable pipeline extracted from a family of tasks.

  - Applicable situations, required inputs, desired outcome, and constraints.

  - Shared stages defined by intermediate outcomes, completion conditions, and necessary dependencies.

  - Transformations defined by required inputs and resulting outcomes, with suggested methods distinguished from required steps.

  - Attachment points for residual task-specific work, including errata, without duplicating or complicating the common core.

  - Independent paths, dependency-specific joins, and shared-resource constraints.

  - Explicit choices, branches, retries, and unresolved gaps where needed.

- Evidence of reuse, preserved outcomes, and improved progress, with untested paths and unresolved bottlenecks explicit.

## Observation (Input)

- Read representative tasks, their required outcomes, inputs, constraints, and existing procedures.

- Compare attempts for recurring outcomes and transformations beneath differences in terminology, methods, and task details.

- Record what remains task-specific without assuming every difference needs a general solution.

- Record where work waits, what releases it, and which dependencies or shared resources are claimed to require that order.

- Seek established processes for the same or analogous problems before inventing one.

## Abduction

_Devise an explanation for observations._

- Propose a common core that explains recurring work, distinguishing genuine commonality from superficial resemblance.

- Use @../op-topology-recomposition/SKILL.md to organize shared intermediate outcomes into stages and isolate residual work into disjoint parts.

- Use @../op-mechanism-alignment/SKILL.md to propose how each transformation produces its outcomes, distinguishing required steps from replaceable methods.

- Parameterize differences when the transformation remains the same. Otherwise attach task-specific work where its outcomes are required rather than building exceptions into every shared stage.

- Apply a fork–join lens to widen the pipeline: independent parts proceed together, and each join waits only for its required outcomes, not every outstanding task.

## Deduction

_Derive consequences of the explanation._

- Trace representative tasks through the proposed core and attachment points, checking that shared stages retain their meaning and no required work disappears.

- Predict which duplication and waits disappear, which dependencies remain, and whether adaptation or coordination costs erase the gains from reuse and parallelism.

- Predict how a delayed, failed, or retried part affects its dependants and what permits unrelated parts to continue.

- Identify observations that distinguish a missing dependency, an ineffective method, and execution that departs from the specification.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply the pipeline to differing tasks within the permitted scope, checking intermediate and final outcomes. Mark unexecuted paths as untested.

- Check whether the core is reused without task-specific exceptions spreading through it, and whether residual work joins without duplication, interference, or unrelated waiting.

- Compare progress, repeated effort, and coordination costs with predictions.

- Revise boundaries, dependencies, or methods where the comparison exposes a defect. Correct execution errors without automatically changing the specification.

- Test revisions against previously supported cases and new variations to distinguish reusable stages from a process fitted to one task.

- Remove stages, steps, or barriers shown unnecessary for required outcomes. Retain parallelism only when it improves progress without violating constraints.

## Iteration

- Re-invoke `process-development` when new tasks reveal further commonality, a forced abstraction, or avoidable waiting.

- Promote recurring residual work into shared stages when its inputs and outcomes support reuse. Return false commonality to task-specific paths.

- Update the reusable specification so later executions benefit from the revision.
