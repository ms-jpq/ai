---
name: conform
description: A semantics-preserving transformation toward applicable rules and local conventions.
---

# Conform

- `conform [src…] dst` transforms the destination using explicit sources or, when omitted, its closest comparable peers.

  - Sources and destinations may be functions, modules, documents, or passages.

  - Change only the destination.

- Use @../op-purpose-formation/SKILL.md when the destination's purpose or preservation boundary is unclear.

- Use @../op-conceptual-synthesis/SKILL.md when inconsistent terms obscure shared meanings or necessary distinctions.

- Use @../op-topology-recomposition/SKILL.md when conformity requires revising organisation or connections between parts.

- Use @../refine/SKILL.md when prose needs rewriting.

---

## Artifact (Output)

- A destination consistent with applicable rules and reference conventions, with its behaviour, contracts, constraints, and meaning preserved.

- Reasons for retained differences and any unresolved conflicts.

---

## Observation (Input)

- Read the destination and explicit sources.

  - When sources are omitted, choose peers by role and scope, not filesystem proximity.

- Read applicable rules in `../../rules/`, including global, path-specific, and embedded-language rules.

- Map corresponding roles and conventions in naming, structure, idioms, terminology, references, and formatting.

- Identify rule violations and differences from references.

- Identify behaviour and meaning to preserve, including deliberate differences from peers.

---

## Abduction

_Devise an explanation for observations._

- Explain each mismatch as a rule violation, inconsistent convention, necessary difference, or unresolved conflict.

- Prefer explicit sources over inferred conventions, subject to applicable rules and semantic preservation.

  - Do not copy rule violations shared by peers.

  - Resolve conflicting examples from context and repeated patterns. Leave unsupported conventions unresolved.

- Propose changes that resolve supported inconsistencies while preserving necessary differences.

---

## Deduction

_Derive consequences of the explanation._

- Predict which rules and conventions each change will satisfy and which differences must remain.

- Derive checks for preserved behaviour, contracts, and meaning, including affected callers and references.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply the proposed changes to the destination.

- Check the revised destination against applicable rules, references, and the original destination.

  - For code, run relevant checks.

  - For prose, verify that claims, conditions, and uncertainty survive.

- Retain changes only when they satisfy the predicted rules and conventions while preserving required semantics.

- Explain retained differences and unresolved conflicts, including conformity that would require semantic changes.
