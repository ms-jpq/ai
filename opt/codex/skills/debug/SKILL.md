---
name: debug
description: Trace a failure to an implementation discrepancy or its earliest deficient model layer, then test and apply a correction.
---

# Debug

- Preserve failing inputs, logs, and system state before changing the system or its model.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Diagnosis:** The implementation discrepancy or model deficiency explaining the failure.

- **Correction:** An implementation or model change that prevents, detects, or contains the failure.

---

## Observation (Input)

_State the input categories and their roles._

- **Failure:** The difference between expected and observed behaviour.

- **System:** The affected implementation and intended model.

- **Reproduction:** Inputs, environment, and steps that trigger the failure.

---

## Abduction

_Devise an explanation for observations._

- Trace the failure through the implicated implementation and model dependencies.

  - Inspect earlier model layers when the current explanation is insufficient.

  - Ask what would have made the failure impossible or detectable earlier.

  - Distinguish a deficient model from an implementation that fails to realize a sound model.

- Classify each supported model deficiency by its earliest layer.

  - Purpose Formation: the purpose, boundary, agreement, or success conditions were deficient.

  - Problem Framing: an obstruction was absent, misclassified, or insufficiently prioritized.

  - Topology Recomposition: components, boundaries, or connections were deficient.

  - Conceptual Synthesis: ambiguous names or collapsed distinctions obscured the relevant meaning.

  - Mechanism Alignment: the proposed causal path or its preconditions failed to cover a salient concern.

- Consider interacting deficiencies.

- Propose a correction to the implementation discrepancy or earliest deficient model layer.

---

## Deduction

_Derive consequences of the explanation._

- Derive the conditions under which the correction prevents, detects, or contains the failure.

- Derive changes to the deficient artifact and its dependents.

- Derive a test that would falsify the diagnosis.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the correction against the reproduction and relevant counterexamples.

- Correct the implementation or update the deficient operator artifact and its dependents.

- Retain the diagnosis only when it explains the failure and its correction holds. Record unresolved causal claims.

---

- Use @../reconcile/SKILL.md when the correction requires resolving discrepancies between things that should agree.

  - Correct the implementation directly when the intended model remains sound.

- Use the operator skill for every layer whose model requires revision.
