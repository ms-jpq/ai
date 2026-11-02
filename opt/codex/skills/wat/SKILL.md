---
name: wat
description: Explain how something works and why it matters using concrete mechanisms and evidence, without jargon or filler.
---

# Wat

## Artifact (Output)

_State the intended properties declaratively._

- **Explanation:** How the subject works and why it matters, in terms the user can follow.

---

## Observation (Input)

_State the input categories and their roles._

- **Subject:** What needs explaining.

- **Reader:** The user's current understanding and confusion.

- **Evidence:** Code, data, observations, and intentions supporting the explanation.

---

## Abduction

_Devise an explanation for observations._

- Identify undefined terms, claims without mechanisms, and missing explanatory steps.

- Propose the simplest explanation that accounts for the evidence.

  - Name what acts, what it acts on, what changes, and under which conditions.

  - Explain why each consequential step follows. Define necessary terms where they first appear.

  - Replace claims such as “robust”, “seamless”, or “powerful” with the specific behaviour they assert. Remove them when they assert nothing.

---

## Deduction

_Derive consequences of the explanation._

- Trace a concrete case from its starting conditions to its result.

- Identify what the explanation predicts and what observation would contradict it.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Check the explanation against the evidence and revise unsupported claims.

  - Distinguish observation, intention, and inference.

- Lead with the answer, then supply the mechanism and consequences needed to understand it.

  - Include the concrete case when it clarifies something the prose leaves abstract.

  - Remove throat-clearing, repeated conclusions, decorative terminology, and detail unrelated to the user's confusion.

---

- Use @../converge/SKILL.md when confusion exposes a gap in the underlying model.

- Use @../refine/SKILL.md to remove unnecessary wording after the explanation is substantively clear.
