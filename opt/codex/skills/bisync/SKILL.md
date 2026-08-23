---
name: bisync
description: Reconcile two system representations while preserving authorized changes and explicit conflicts.
---

Use @../op-problem-framing/SKILL.md when a difference lacks an agreed direction.

Use @../op-conceptual-synthesis/SKILL.md when the representations use incompatible terms.

# Bisync

`bisync <src> <dst>` reconciles two representations of one system.

- Typical operands are a system description and the system itself.

- `src` and `dst` are peers during diagnosis.

- Authority, evidence, and intent determine which representation changes.

## Observation

- Select the shared system and the relevant scope of both representations.

- Read each representation before changing either one.

- Map corresponding claims, elements, relations, and constraints.

- Classify every difference:

  - Both agree.

  - One is absent.

  - They disagree.

  - Their correspondence is unknown.

## Abduction

_Devise an explanation for each difference._

- Classify its likely cause:

  - Stale representation.

  - Unintended system drift.

  - Authorized difference.

  - Incomplete model.

  - Unresolved conflict.

- Propose the smallest authorized reconciliation.

- Preserve a conflict when available evidence does not establish a direction.

## Deduction

_Derive consequences of the reconciliation hypothesis._

- Predict the resulting correspondence between the representations.

- Predict which differences remain authorized, unknown, or explicitly unresolved.

- Predict the behavior, constraints, or decisions affected by each changed claim.

## Induction

_Test those consequences and provisionally retain or revise the reconciliation._

- Re-read both representations after every change.

- Verify changed claims against the system's observable behavior and constraints.

- Retain only reconciliations supported by evidence and authority.

- Report changes by representation, preserved differences, and unresolved conflicts.
