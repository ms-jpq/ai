---
name: bisync
description: Reconcile two system representations while preserving authorized changes and explicit conflicts.
---

# Bisync

`bisync <src> <dst>` reconciles two representations of one system.

- Typical operands are a model and the system it represents.

- Establish the reconciliation direction from authority, evidence, and intent.

Use @../op-purpose-formation/SKILL.md when the system purpose or reconciliation boundary is unclear.

Use @../op-problem-framing/SKILL.md when a difference lacks an agreed direction.

Use @../op-conceptual-synthesis/SKILL.md when the representations use incompatible terms.

Use @../op-mechanism-alignment/SKILL.md when a difference could leave a salient concern without mechanism coverage.

## Observation

- Delimit the shared system and the relevant scope of both representations.

- Take its system purpose, boundary, authority, and commitments as reconciliation constraints.

- Read each representation before changing either one.

- Map corresponding claims, parts, relations, and constraints.

- Classify every difference:

  - Both agree.

  - One is absent.

  - They disagree.

  - Their correspondence is unknown.

- Record the authority, evidence, and intent available for each difference.

- Prioritize differences that could obstruct the system purpose or mechanism coverage.

## Abduction

_Devise an explanation for observations._

- Classify its change provenance:

  - Only `src` changed from a common base.

  - Only `dst` changed from a common base.

  - Both changed independently from a common base.

  - No common base is known.

- Name the reconciliation disposition:

  - `src ← dst`.

  - `dst ← src`.

  - `src`, `dst` → a shared state.

  - Retain authorized divergence.

  - Defer.

- State the authority, evidence, and intent that authorize the disposition.

## Deduction

_Derive consequences of the explanation._

- Derive the expected correspondence after each disposition.

- Derive whether each disposition preserves the system purpose and required mechanism coverage.

- Identify the claims that must change, remain divergent, or remain unresolved under each disposition.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply only the proposed, authorized changes.

- Re-read both representations and verify changed claims against the system's purpose, behavior, and constraints.

- Retain a disposition only when the resulting correspondence matches its prediction.

- Report changes by representation, preserved differences, and unresolved conflicts.
