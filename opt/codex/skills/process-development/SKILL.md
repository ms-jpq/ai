---
name: process-development
description: Extract reusable stages from varied tasks and organize them into efficient pipelines.
---

# Process Development

- Use @../converge/SKILL.md when the process's purpose, concerns, outcome dependencies, or mechanisms need clarification.

- Use @../op-topology-recomposition/SKILL.md during abduction to organize shared intermediate outcomes into stages and isolate residual work into disjoint parts.

- Use @../op-mechanism-alignment/SKILL.md during abduction to propose how each transformation produces its outcomes, distinguishing required steps from replaceable methods.

---

## Artifact (Output)

_State the intended properties declaratively._

- A reusable pipeline preserves the required outcomes across its stated family of tasks.

  - Applicability, inputs, outcomes, and constraints are explicit.

  - Shared stages retain their meaning across tasks, with defined intermediate outcomes, completion conditions, and necessary dependencies.

  - Transformations connect required inputs to resulting outcomes, with suggested methods distinguished from required steps.

  - Residual task-specific work, including errata, joins where its outcomes are needed without duplicating or complicating the common core.

  - Independent paths proceed together within shared-resource constraints. Each join waits only for its required outcomes.

  - Choices, branches, retries, and unresolved gaps are explicit where needed.

- Claims of reuse, preserved outcomes, and improved progress have supporting evidence.

  - Untested paths and unresolved bottlenecks remain explicit.

---

## Observation (Input)

_State the input categories and their roles._

- Representative tasks, required outcomes, inputs, and constraints define the family the pipeline should support.

- Existing procedures and execution attempts provide candidate stages and evidence of recurring or task-specific work.

- Recorded waits, release conditions, and claimed dependencies or resource constraints explain the current ordering.

---

## Abduction

_Devise an explanation for observations._

- Seek established processes for the same or analogous problems before inventing one.

- Propose a common core that explains recurring work.

  - Compare attempts for recurring outcomes and transformations beneath differences in terminology, methods, and task details.

  - Parameterize differences when the transformation remains the same. Otherwise attach task-specific work where its outcomes are required.

- Apply a fork–join lens to widen the pipeline: independent parts proceed together, and each join waits only for its required outcomes.

---

## Deduction

_Derive consequences of the explanation._

- Trace representative tasks through the proposed core and attachment points, checking that shared stages retain their meaning and no required work disappears.

- Predict which duplication and waits disappear, which dependencies remain, and whether adaptation or coordination costs erase the gains from reuse and parallelism.

- Predict how a delayed, failed, or retried part affects its dependants and what permits unrelated parts to continue.

- Identify observations that distinguish a missing dependency, an ineffective method, and execution that departs from the specification.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply the pipeline to differing tasks within the permitted scope, checking intermediate and final outcomes. Mark unexecuted paths as untested.

- Check whether the core is reused without task-specific exceptions spreading through it, and whether residual work joins without duplication, interference, or unrelated waiting.

- Compare progress, repeated effort, and coordination costs with predictions.

- Revise boundaries, dependencies, or methods where the comparison exposes a defect. Correct execution errors without automatically changing the specification.

  - Test revisions against previously supported cases and new variations to distinguish reusable stages from a process fitted to one task.

- Remove stages, steps, or barriers shown unnecessary for required outcomes. Retain parallelism only when it improves progress without violating constraints.

---

## Application

- Re-invoke `process-development` when new tasks reveal further commonality, a forced abstraction, or avoidable waiting.

- Promote recurring residual work into shared stages when its inputs and outcomes support reuse. Return false commonality to task-specific paths.

- Update the reusable specification so later executions benefit from the revision.
