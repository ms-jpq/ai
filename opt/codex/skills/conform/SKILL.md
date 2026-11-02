---
name: conform
description: A semantics-preserving transformation toward applicable rules and local conventions.
---

# Conform

- `conform [src…] dst` transforms the subject (`dst`) using explicit sources or, when omitted, its closest comparable peers.

  - Sources and subjects may be functions, modules, documents, or passages.

  - Change only the subject.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Conformed subject:** The subject follows applicable rules and local conventions while preserving its meaning and behaviour.

---

## Observation (Input)

_State the input categories and their roles._

- **Subject:** What to conform, including the meaning, behaviour, and deliberate differences to preserve.

- **References:** Explicit sources or peers comparable by role and scope.

- **Rules:** Applicable requirements from `../../rules/`, including embedded languages.

---

## Abduction

_Devise an explanation for observations._

- Compare the subject's conventions with its references and applicable rules, matching elements by role.

- Explain each mismatch as a rule violation, inconsistent convention, necessary difference, or unresolved conflict.

- Prefer explicit sources over inferred conventions, subject to applicable rules and semantic preservation.

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

- Apply the proposed changes to the subject.

- Check the result against the rules, references, and original subject. Retain changes that conform and preserve semantics.

  - For prose, verify that claims, conditions, and uncertainty survive.

- Explain retained differences and unresolved conflicts, including conformity that would require semantic changes.

---

- Use @../op-purpose-formation/SKILL.md when the subject's purpose or what must be preserved is unclear.

- Use @../op-conceptual-synthesis/SKILL.md when inconsistent terms obscure shared meanings or necessary distinctions.

- Use @../op-topology-recomposition/SKILL.md when conformity requires revising organization or connections between parts.

- Use @../refine/SKILL.md when prose needs rewriting.
