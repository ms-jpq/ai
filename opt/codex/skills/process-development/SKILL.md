---
name: process-development
description: Extract reusable stages from varied tasks and organize them into efficient pipelines.
---

# Process Development

## Artifact (Output)

_State the intended properties declaratively._

- **Pipeline:** Reusable stages and dependencies that produce the required outcomes across a defined family of tasks.

---

## Observation (Input)

_State the input categories and their roles._

- **Tasks:** Representative cases, their inputs, required outcomes, and constraints.

- **Procedures:** Existing steps and dependencies to generalize or revise.

- **Execution evidence:** Attempts, waits, and resource use that reveal recurring work and bottlenecks.

---

## Abduction

_Devise an explanation for observations._

- Seek established processes for the same or analogous problems before inventing one.

- Propose a common core that explains recurring work.

  - Define each stage's inputs, transformation, outcomes, and completion conditions.

  - Compare attempts for recurring outcomes and transformations beneath differences in terminology, methods, and task details.

  - Parameterize differences when the transformation remains the same. Otherwise attach task-specific work where its outcomes are required.

- Propose parallel stages for independent work, with each join waiting only for its required outcomes.

---

## Deduction

_Derive consequences of the explanation._

- Trace representative tasks through the shared and task-specific stages, checking their meaning and coverage of required work.

- Predict which duplication and waits disappear, which dependencies remain, and whether adaptation or coordination costs erase the gains from reuse and parallelism.

- Predict how a delayed, failed, or retried part affects its dependants and what permits unrelated parts to continue.

- Identify observations that distinguish a missing dependency, an ineffective method, and execution that departs from the specification.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply the pipeline to differing tasks within the permitted scope, checking intermediate and final outcomes. Mark unexecuted paths as untested.

- Check whether the core is reused without task-specific exceptions spreading through it, and whether residual work joins without duplication, interference, or unrelated waiting.

- Compare progress, repeated effort, and coordination costs with predictions.

- Revise boundaries, dependencies, methods, or execution where the comparison exposes a defect.

  - Test revisions against previously supported cases and new variations to distinguish reusable stages from a process fitted to one task.

- Remove stages, steps, or barriers shown unnecessary for required outcomes.

---

## Application

- Promote recurring task-specific work into shared stages when its inputs and outcomes support reuse. Separate stages whose differences prevent reuse.

---

- Use @../converge/SKILL.md when the process's purpose, concerns, outcome dependencies, or mechanisms need clarification.

- Use @../op-topology-recomposition/SKILL.md during abduction to organize shared intermediate outcomes into stages and isolate residual work into disjoint parts.

- Use @../op-mechanism-alignment/SKILL.md during abduction to propose how each transformation produces its outcomes, distinguishing required steps from replaceable methods.
