---
name: gap-analysis
description: Discover consequential omissions relative to a purpose, reassessing coverage without introducing unnecessary scope.
---

# Gap Analysis

- Apply to concerns, questions, features, mechanisms, outcomes, or another level of the system.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Gaps:** Missing coverage, ranked by its consequences for the purpose and distinguished from uncertain coverage.

---

## Observation (Input)

_State the input categories and their roles._

- **Purpose:** The intended achievement and scope against which coverage is judged.

- **Provisions:** What currently addresses that purpose.

- **Evidence:** Observations and prior findings supporting coverage assessments.

---

## Abduction

_Devise an explanation for observations._

- Distinguish existing coverage, deliberate exclusions, unresolved areas, and previously dismissed gaps using their supporting reasons.

- Propose omissions that could obstruct the purpose, considering relevant situations, dependencies, and failure conditions beyond those already represented.

- Explain what coverage each candidate adds.

  - Consider whether existing provisions cover the need indirectly.

---

## Deduction

_Derive consequences of the explanation._

- Predict what becomes impossible, unreliable, or materially worse if the suspected gap remains.

  - Identify a case or observation that would distinguish missing coverage from adequate coverage.

- Describe the coverage needed without assuming a particular implementation or expanding the purpose.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Check the predictions against the material, cases, and evidence.

- Discard duplicates, already-covered needs, and additions without a consequential connection to the purpose.

- Prioritize supported gaps by their consequences, distinguishing them from unverified possibilities.

- Return no gaps when none are supported.

---

## Application

- Re-invoke `gap-analysis` to explore areas overlooked in prior findings.

- Reconsider dismissed gaps when their premises change. Report newly found or revised gaps and material uncertainties.

- The caller chooses how to address findings. A gap does not itself authorize new features, implementation, or scope changes.

---

- Use @../op-purpose-formation/SKILL.md when the purpose or scope needs clarification.

- Use @../op-problem-framing/SKILL.md when a suspected omission requires revising the problem frame or its concerns.

- Use @../op-mechanism-alignment/SKILL.md during abduction when indirect coverage depends on an unclear causal path.
