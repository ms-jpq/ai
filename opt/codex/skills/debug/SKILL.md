---
name: debug
description: Trace a failure to an implementation discrepancy or its earliest deficient model layer, then test and apply a correction.
---

# Debug

- Use @../bisync/SKILL.md after diagnosis establishes which model or system differences require correction.

- Use the operator skill for every layer whose model requires revision.

## Artifact (Output)

- A failure account with the expected outcome, observed outcome, evidence, and affected system.

- A diagnosis identifying an implementation discrepancy or the earliest supported deficient model layer, with its downstream consequences.

  - Purpose Formation: the purpose, boundary, agreement, or success conditions were deficient.

  - Problem Framing: an obstruction was absent, misclassified, or insufficiently prioritised.

  - Topology Recomposition: a concern lacked local structural embodiment.

  - Conceptual Synthesis: ambiguous names or collapsed distinctions obscured the relevant meaning.

  - Mechanism Alignment: coverage, causal path, or assumptions were deficient.

- A corrective revision, its evidence, and the condition that would reopen the diagnosis.

## Observation (Input)

- Record the expected and observed outcomes, their difference, and the affected system.

- Collect evidence from the system, its intended model, and relevant decisions.

- Map model and system differences without changing either representation.

- Preserve the evidence needed to reproduce or explain the failure.

- Record the model assumptions and dependencies relevant to the observed failure.

## Abduction

_Devise an explanation for observations._

- Trace the failure through the implicated implementation and model dependencies.

  - Inspect earlier model layers when evidence implicates them or the current explanation is insufficient.

  - Ask what would have made the failure impossible or detectable earlier.

  - Distinguish a deficient model from an implementation that fails to realise a sound model.

- Classify each supported model deficiency by its earliest layer.

  - Permit several interacting deficiencies.

  - Keep an unsupported causal claim unresolved.

- Propose a correction to the implementation discrepancy or earliest deficient model layer.

## Deduction

_Derive consequences of the explanation._

- Derive the conditions under which the correction prevents, detects, or contains the failure.

- Derive changes to the deficient artifact and its dependents.

- Predict evidence that would falsify the diagnosis.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the correction against the failure evidence and relevant counterexamples.

- Correct the implementation or update the deficient operator artifact and its dependents, according to the diagnosis.

- Retain the diagnosis only when it explains the failure and its correction holds.

- Reopen the diagnosis when later evidence contradicts it or the failure recurs.
