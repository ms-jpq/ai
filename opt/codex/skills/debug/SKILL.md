---
name: debug
description: Trace a failure to an implementation discrepancy or its earliest deficient model layer, then test and apply a correction.
---

# Debug

- Use @../bisync/SKILL.md when the diagnosed correction requires reconciling maintained representations. Correct an implementation discrepancy directly when the intended model remains sound.

- Use the operator skill for every layer whose model requires revision.

- Preserve evidence needed to reproduce or explain the failure before changing the system or its model.

---

## Artifact (Output)

_State the intended properties declaratively._

- The corrected implementation or model prevents, detects, or contains the failure under the identified conditions, with affected dependents updated.

  - Checks against the original failure and relevant counterexamples support the correction.

- The diagnosis explains the failure through an implementation discrepancy or the earliest supported deficient model layer and its downstream consequences.

- Unresolved causal claims and conditions that would reopen the diagnosis remain explicit.

---

## Observation (Input)

_State the input categories and their roles._

- Expected and observed outcomes: the discrepancy requiring explanation.

- Affected system and intended model: the implementation, assumptions, and dependencies through which the failure may arise.

- Available observations, reproduction evidence, and relevant decisions: support for tracing and testing possible causes.

---

## Abduction

_Devise an explanation for observations._

- Compare the model and system without changing either representation.

- Trace the failure through the implicated implementation and model dependencies.

  - Inspect earlier model layers when evidence implicates them or the current explanation is insufficient.

  - Ask what would have made the failure impossible or detectable earlier.

  - Distinguish a deficient model from an implementation that fails to realize a sound model.

- Classify each supported model deficiency by its earliest layer.

  - Purpose Formation: the purpose, boundary, agreement, or success conditions were deficient.

  - Problem Framing: an obstruction was absent, misclassified, or insufficiently prioritized.

  - Topology Recomposition: outcome dependencies, part boundaries, or connections were deficient.

  - Conceptual Synthesis: ambiguous names or collapsed distinctions obscured the relevant meaning.

  - Mechanism Alignment: the proposed causal path or its preconditions failed to cover a salient concern.

- Allow several interacting deficiencies, while keeping unsupported causal claims unresolved.

- Propose a correction to the implementation discrepancy or earliest deficient model layer.

---

## Deduction

_Derive consequences of the explanation._

- Derive the conditions under which the correction prevents, detects, or contains the failure.

- Derive changes to the deficient artifact and its dependents.

- Predict evidence that would falsify the diagnosis.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the correction against the failure evidence and relevant counterexamples.

- Correct the implementation or update the deficient operator artifact and its dependents, according to the diagnosis.

- Retain the diagnosis only when it explains the failure and its correction holds.

  - Reopen the diagnosis when later evidence contradicts it or the failure recurs.
