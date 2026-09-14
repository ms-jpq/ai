---
name: process-development
description: Develop reusable processes by specifying intermediate outcomes, testing how they are achieved, and revising the specification through use.
---

# Process Development

Use @../converge/SKILL.md when the process's purpose, concerns, outcome dependencies, or mechanisms need clarification.

## Artifact (Output)

- A reusable process specification for a recurring problem class.

  - Applicable situations, required inputs, desired outcome, and constraints.

  - Named intermediate outcomes, their dependencies, and observable conditions for achieving or maintaining them.

  - Transformations defined by required inputs and resulting outcomes, with suggested methods distinguished from required steps.

  - Explicit choices, branches, retries, and unresolved gaps where needed.

- Evidence from use that supports the specification or identifies where it needs revision.

## Observation (Input)

- Record the recurring problem, desired outcome, available inputs, and relevant concerns.

- Read existing procedures and inspect representative attempts, including failures and workarounds.

- Identify which conditions recur and which vary between instances.

- Seek established processes for the same or analogous problems before inventing one.

## Abduction

_Devise an explanation for observations._

- Propose intermediate outcomes and explain how their dependencies make the desired outcome achievable.

- Specify how each outcome can be verified before choosing how to produce it.

- Connect outcomes through necessary dependencies, leaving independent work unordered.

- Reuse or adapt known methods for each transformation, leaving alternatives open unless the method itself is required.

- Express recurring variation as parameters or conditional paths rather than separate copies of the process.

## Deduction

_Derive consequences of the explanation._

- Trace representative inputs through the proposed process to derive intermediate and final results.

- Check whether each result supplies what its dependent transformations require.

- Predict where missing inputs, failed checks, or repeated attempts would prevent progress, and what would permit recovery.

- Derive observations that distinguish missing or incompatible requirements, an ineffective method, and execution that departs from the specification.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Run representative cases within the task's permitted scope. Mark unexecuted paths as untested.

- Compare actual intermediate and final outcomes with their specified conditions.

- Revise the outcomes, dependencies, or methods according to the observed failure. Correct execution errors without automatically changing the specification.

- Test revisions against previously supported cases to distinguish a reusable improvement from a case-specific workaround.

- Remove intermediate outcomes or required steps when testing shows they are unnecessary for the desired outcome and its constraints.

## Iteration

- Re-invoke `process-development` when use exposes a failure, workaround, or recurring variation.

- Update the reusable specification so later executions benefit from the revision.
