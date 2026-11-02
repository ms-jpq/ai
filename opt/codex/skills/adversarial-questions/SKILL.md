---
name: adversarial-questions
description: Derive questions from a purpose and its concerns, building a reusable question bank through application and revision.
---

# Adversarial Questions

## Artifact (Output)

_State the intended properties declaratively._

- **Questions:** Distinct, unanswered questions prioritized by the concerns they address.

- **Question bank:** Reusable questions linked to their purposes, concerns, and applicability conditions.

---

## Observation (Input)

_State the input categories and their roles._

- **Purpose and concerns:** What the questions should help address.

- **Context:** The situation, constraints, and prior answers.

- **Question bank:** Existing questions to adapt.

---

## Abduction

_Devise an explanation for observations._

- Identify what needs to be understood or decided about each concern, in priority order.

- Adapt relevant bank entries and generate questions for concerns they do not cover.

---

## Deduction

_Derive consequences of the explanation._

- Predict how plausible answers would change understanding, a decision, or an action relevant to the concern.

  - Identify what information would distinguish those answers and whether it is already available.

- Check whether the question still matters if the current implementation or proposed solution changes.

- Separate reusable questions arising from the concern from details specific to this situation.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Remove answered, duplicate, or inconsequential questions and revise false premises or leading formulations.

- When answers or changed work become available, check whether the questions helped address their concerns and revise the mappings accordingly.

- Retain useful mappings in the Question Bank with their motivating purposes, concerns, and applicability conditions.

  - Retire a question for the current work when answered without discarding its reusable form or the underlying concern.

---

## Application

- Apply before action, after material changes, and before completion.

- Direct questions to the working agent or caller, including yourself during self-review.

- The caller owns answers, experiments, implementation, and acceptance.

- Involve the user for unresolved requirements, tradeoffs they must choose, or additional permission.

---

## Question Bank

- Easy change → simplicity: What could disappear while the requirements still hold?

- Safe change → compatibility: Which existing caller would behave differently?

- Useful communication → prior knowledge: What does the reader already know, and what must be explained?

---

- Use @../op-purpose-formation/SKILL.md when the purpose needs clarification.

- Use @../op-problem-framing/SKILL.md to establish or revise the concerns and priorities from which questions are derived.

- Use @../gap-analysis/SKILL.md to discover missing concerns or gaps in question coverage.
