---
name: wat
description: Explain how something works and why it matters using concrete mechanisms and evidence, without jargon or filler.
---

# Wat

- Use @../converge/SKILL.md when confusion exposes a gap in the underlying model.

- Use @../refine/SKILL.md to remove unnecessary wording after the explanation is substantively clear.

---

## Artifact (Output)

_State the intended properties declaratively._

- An explanation the user can use to predict behaviour, understand a consequence, or make a decision.

  - It explains what acts, what changes, under which conditions, and why consequential steps follow.

  - Claims agree with available evidence, and observation, intention, inference, and uncertainty remain distinguishable.

---

## Observation (Input)

_State the input categories and their roles._

- Subject and surrounding conversation: what needs explaining and the user's current understanding.

- Relevant code, data, observations, and stated intentions: evidence for explaining how the subject works.

---

## Abduction

_Devise an explanation for observations._

- Identify undefined terms, claims without mechanisms, and missing explanatory steps, distinguishing observed behaviour, intended behaviour, and inference.

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

- Check the explanation against the evidence and revise unsupported claims. State what remains unknown.

- Lead with the answer, then supply the mechanism and consequences needed to understand it.

  - Include the concrete case when it clarifies something the prose leaves abstract.

  - Remove throat-clearing, repeated conclusions, decorative terminology, and detail unrelated to the user's confusion.

  - Preserve necessary distinctions. Shorter wording is useful only when the explanation remains sufficient.
