---
name: conform
description: Conform code or prose to explicit references or comparable peers without changing behaviour or meaning.
---

# Conform

- `conform [src…] dst` transforms the destination using explicit sources or, when omitted, its closest comparable peers.

- Sources and destinations may be functions, modules, documents, or passages. Change only the destination.

- Use @../op-purpose-formation/SKILL.md when the destination's purpose or preservation boundary is unclear.

- Use @../op-conceptual-synthesis/SKILL.md when inconsistent terms obscure shared meanings or necessary distinctions.

- Use @../op-topology-recomposition/SKILL.md when conformity requires revising organisation or connections between parts.

- Use @../refine/SKILL.md when conforming prose requires rewriting its wording.

---

## Artifact (Output)

- A destination consistent with applicable reference conventions, with its behaviour, contracts, constraints, and meaning preserved.

- Explicit justified differences and unresolved convention conflicts.

---

## Observation (Input)

- Read the destination, applicable rules, and explicit sources.

- When sources are omitted, inspect peers with comparable roles and scope. Prefer relevant peers over mere filesystem proximity.

- Map corresponding roles and conventions in naming, structure, idioms, terminology, references, and formatting.

- Identify what the destination must preserve, including deliberate differences from its peers.

---

## Abduction

_Devise an explanation for observations._

- Explain each mismatch as an inconsistent convention, a necessary difference, or an unresolved conflict, using the sources and destination's requirements as evidence.

- Prefer explicit sources over inferred conventions, subject to applicable rules and semantic preservation.

- Resolve conflicting examples from their context and repeated patterns. Leave unsupported conventions unresolved rather than copying isolated quirks.

- Propose changes that resolve supported inconsistencies while preserving necessary differences.

---

## Deduction

_Derive consequences of the explanation._

- Predict which conventions each change will satisfy and which differences must remain.

- Derive the behaviour, contracts, and meaning that should remain observable after the transformation.

- Derive checks that would expose lost distinctions, changed contracts, or altered behaviour, including affected callers and references.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply the proposed changes to the destination.

- Test the predictions against the references and the original destination.

- Run relevant checks for code changes. For prose, verify that claims, conditions, and uncertainty survive the revision.

- Retain a change only when it achieves the predicted conformity without changing required semantics.

- Explain retained differences and unresolved conflicts, including conformity that would require semantic changes.
