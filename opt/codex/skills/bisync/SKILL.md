---
name: bisync
description: Reconcile two system representations while preserving authorized changes and explicit conflicts.
---

# Bisync

- `bisync <src> <dst>` reconciles two representations of one system, such as a model and the system it represents.

- Use @../op-purpose-formation/SKILL.md when the system purpose or reconciliation boundary is unclear.

- Use @../op-problem-framing/SKILL.md when the problems or concerns implicated by a difference are unclear.

- Use @../op-conceptual-synthesis/SKILL.md when the representations use incompatible terms.

- Use @../op-mechanism-alignment/SKILL.md when a difference could leave a salient concern without mechanism coverage.

- Use @../op-topology-recomposition/SKILL.md when reconciliation requires revising outcomes, boundaries, or connections between parts.

---

## Artifact (Output)

_State the intended properties declaratively._

- Reconciled claims satisfy the required correspondence without losing authorized changes or violating the system's purpose and constraints.

- Remaining differences are authorized divergences or unresolved conflicts, with their evidence and disposition.

  - Dispositions identify changes by representation and their supporting authority and intent.

---

## Observation (Input)

_State the input categories and their roles._

- Representations: the claims, parts, relations, and constraints to reconcile within the shared system's scope.

- Purpose, boundaries, authority, and commitments: constraints on permitted reconciliation.

- Available evidence and intent: grounds for explaining differences and choosing which changes to preserve.

- Change history and any common base: evidence of which representation changed.

---

## Abduction

_Devise an explanation for observations._

- Map corresponding elements as agreeing, absent on one side, disagreeing, or unknown.

- Where a common base exists, distinguish changes to neither, one, or both representations. Record when no common base is known.

- Prioritize differences that could obstruct the system purpose or mechanism coverage.

- Name the reconciliation disposition:

  - `src ← dst`.

  - `dst ← src`.

  - `src`, `dst` → a shared state.

  - Retain authorized divergence.

  - Defer.

- State the permission, evidence, and intended correspondence supporting the disposition. Defer when permission or intent remains unresolved.

  - Explain how the disposition preserves authorized changes.

---

## Deduction

_Derive consequences of the explanation._

- Derive which claims should change, agree, remain divergent, or remain unresolved after each disposition, and how to check them.

- Derive whether each disposition preserves the system purpose and required mechanism coverage.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply only the proposed, authorized changes.

- Re-read both representations and verify changed claims against the system's purpose, behaviour, and constraints.

- Retain a disposition only when the resulting correspondence matches its prediction.
