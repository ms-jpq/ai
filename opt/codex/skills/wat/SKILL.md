---
name: wat
description: Explain how something works and why it matters using concrete mechanisms and evidence, without jargon or filler.
---

# Wat

- Use @../converge/SKILL.md when confusion exposes a gap in the underlying model.

- Use @../refine/SKILL.md to remove unnecessary wording after the explanation is substantively clear.

---

## Artifact (Output)

- An explanation the user can use to predict behaviour, understand a consequence, or make a decision.

---

## Observation (Input)

- Read the subject and surrounding conversation to identify what needs explaining.

- Inspect the relevant code, data, or evidence. Separate observed behaviour, intended behaviour, and inference.

- Find terms without definitions, claims without mechanisms, and missing steps in the explanation.

---

## Abduction

_Devise an explanation for observations._

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
