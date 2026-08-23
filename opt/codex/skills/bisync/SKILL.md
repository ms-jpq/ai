---
name: bisync
description: Reconcile two system representations while preserving authorized changes and explicit conflicts.
---

# Bisync

`bisync <src> <dst>` reconciles two representations of one system.

- Typical operands are a model and the system it represents.

- Establish the reconciliation direction from authority, evidence, and intent.

Use @../op-problem-framing/SKILL.md when a difference lacks an agreed direction.

Use @../op-conceptual-synthesis/SKILL.md when the representations use incompatible terms.

## Observation

- Delimit the shared system and the relevant scope of both representations.

- Read each representation before changing either one.

- Map corresponding claims, parts, relations, and constraints.

- Classify every difference:

  - Both agree.

  - One is absent.

  - They disagree.

  - Their correspondence is unknown.

- Record the authority, evidence, and intent available for each difference.

## Abduction

_Devise an explanation and reconciliation direction for each difference._

- Classify its likely cause:

  - Stale representation.

  - Unintended system drift.

  - Authorized difference.

  - Incomplete model.

  - Unresolved conflict.

- Propose a disposition:

  - Change `src` to match `dst`.

  - Change `dst` to match `src`.

  - Change both representations.

  - Preserve an authorized difference.

  - Defer an unresolved conflict.

- State the authority, evidence, and intent that authorize the disposition.

## Deduction

_Derive consequences of the reconciliation hypothesis._

- Derive the expected correspondence after each disposition.

- Identify the claims, behavior, constraints, or decisions affected by each change.

- Identify every difference expected to remain authorized or unresolved.

## Induction

_Test those consequences and provisionally retain or revise the reconciliation._

- Apply only the proposed, authorized changes.

- Re-read both representations and verify changed claims against the system's observable behavior and constraints.

- Retain a disposition only when the resulting correspondence matches its prediction.

- Report changes by representation, preserved differences, and unresolved conflicts.
