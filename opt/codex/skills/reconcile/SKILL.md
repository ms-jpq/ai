---
name: reconcile
description: Reconcile discrepancies between things that should agree and surface unresolved conflicts.
---

# Reconcile

- The two sides may be design and code, design and planned work, or schema and data.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Agreement:** Discrepancies resolved according to each side's role and the relationship between them.

- **Conflicts:** Unresolved disagreements and the decisions needed to resolve them.

---

## Observation (Input)

_State the input categories and their roles._

- **Sides:** The two things to reconcile and their respective roles.

- **Relationship:** What must agree, what may differ, and which claims each side governs.

- **Constraints:** Purpose, boundaries, and authority governing permitted changes.

- **History:** Changes and decisions explaining differences.

---

## Abduction

_Devise an explanation for observations._

- Map corresponding elements as agreeing, absent on one side, disagreeing, or unknown.

- Use change history to explain how discrepancies arose, comparing against a common base where one exists.

- Prioritize differences that could obstruct the system purpose or mechanism coverage.

- Propose how to resolve each discrepancy:

  - Revise one side to satisfy the other.

  - Revise both to satisfy their shared obligations.

  - Retain a difference justified by their distinct roles.

  - Surface an unresolved conflict.

---

## Deduction

_Derive consequences of the explanation._

- Derive what should change, agree, remain different, or remain unresolved after each proposal, and how to check it.

- Check whether the proposed changes preserve each side's purpose and constraints.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply the changes and check both sides against their intended relationship.

- Retain resolutions supported by those checks and surface remaining conflicts.

---

- Use @../op-purpose-formation/SKILL.md when the system purpose or reconciliation boundary is unclear.

- Use @../op-problem-framing/SKILL.md when the problems or concerns implicated by a difference are unclear.

- Use @../op-conceptual-synthesis/SKILL.md when the two sides use incompatible terms.

- Use @../op-mechanism-alignment/SKILL.md when a difference could leave a salient concern without mechanism coverage.

- Use @../op-topology-recomposition/SKILL.md when reconciliation requires revising components, boundaries, or connections.
