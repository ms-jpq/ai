---
name: debug
description: Trace a failure to its earliest deficient model layer and revise that layer.
---

# Debug

Use @../bisync/SKILL.md when the intended model and realized system may differ.

Use the operator skill for every layer whose model requires revision.

## Artifact

- A failure account with the expected outcome, observed outcome, evidence, and affected system.

- A layered diagnosis of the failure.

  - Purpose Formation: the purpose, boundary, authority, or success conditions were deficient.

  - Problem Framing: an obstruction was absent, misclassified, or insufficiently prioritized.

  - Topology Recomposition: a concern lacked local structural embodiment.

  - Mechanism Alignment: coverage, causal path, or assumptions were deficient.

- The earliest supported deficient layer and its downstream consequences.

- A corrective revision, its evidence, and the condition that would reopen the diagnosis.

## Observation

- Record the expected and observed outcomes, their difference, and the affected system.

- Collect evidence from the system, its intended model, and relevant decisions.

- Reconcile model and system differences before attributing the failure to either one.

- Record the system purpose, framed problems, salient concerns, topology, and mechanisms in effect.

## Abduction

_Devise an explanation for observations._

- Trace the failure through each layer of the model.

  - Ask what would have made the failure impossible or detectable earlier.

- Classify each supported deficiency by its earliest layer.

  - Permit several interacting deficiencies.

  - Keep an unsupported causal claim unresolved.

- Propose a correction at the earliest deficient layer.

  - Derive downstream changes instead of patching only the observed symptom.

## Deduction

_Derive consequences of the explanation._

- Derive the conditions under which the correction prevents, detects, or contains the failure.

- Predict which purpose, problem, topology, or mechanism artifact must change.

- Predict evidence that would falsify the layer diagnosis.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the correction against the failure evidence and relevant counterexamples.

- Update the deficient operator artifact and its dependent artifacts.

- Retain the diagnosis only when the revised model explains the failure and its correction holds.

- Reopen the diagnosis when later evidence contradicts it or recurrence appears.
