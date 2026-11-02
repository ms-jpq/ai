---
name: adversarial-questions
description: Derive questions from a purpose and its concerns, building a reusable question bank through application and revision.
---

# Adversarial Questions

- Use @../op-purpose-formation/SKILL.md when the purpose needs clarification.

- Use @../op-problem-framing/SKILL.md to establish or revise the concerns and priorities from which questions are derived.

- Use @../gap-analysis/SKILL.md to discover missing concerns or gaps in question coverage.

---

## Artifact (Output)

_State the intended properties declaratively._

- Each question traces to a concern and its motivating purpose, with answers that could change understanding, a decision, or an action.

- The set contains only unanswered, distinct questions, prioritized by concern and current usefulness.

  - An empty set is valid.

- Reusable question-bank mappings retain their motivating purposes, concerns, and applicability conditions, with revisions supported by experience.

---

## Observation (Input)

_State the input categories and their roles._

- Purpose, constraints, and known concerns establish what the questions should help address.

- The current situation, available evidence, and prior answers distinguish established knowledge from remaining uncertainty.

- The Question Bank supplies candidate concern-to-question mappings, not a checklist to apply wholesale.

---

## Abduction

_Devise an explanation for observations._

- Propose what needs to be understood or decided about the framed concerns, using their priorities to focus the questions.

  - Let the concern determine whether to ask about understanding, options, evidence, coordination, simplification, or another response.

- Derive questions from consequential gaps and known concerns.

- Adapt relevant bank entries and generate questions where the bank provides no suitable mapping.

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

- Test each proposed mapping against the stated purpose, actual situation, and available evidence.

- Remove answered, duplicate, or inconsequential questions and revise false premises or leading formulations.

- Return the remaining questions prioritized by concern and usefulness now, without supplying unestablished answers.

- When answers or changed work become available, check whether the questions helped address their concerns and revise the mappings accordingly.

- Retain useful mappings in the Question Bank with their motivating purposes, concerns, and applicability conditions.

  - Retire a question for the current work when answered without discarding its reusable form or the underlying concern.

---

## Application

- Apply before action, after material changes, and before completion.

- Direct questions to the working agent or caller, including yourself during self-review.

- The caller owns answers, experiments, implementation, and acceptance. The output is questions, not a readiness verdict or a required competing implementation.

- Involve the user only for unresolved requirements, tradeoffs they must choose, or additional permission. Question generation does not broaden scope or relax constraints.

- Return questions and necessary context, not the deliberation used to generate them.

- Re-invoke `adversarial-questions` as work and evidence change, not to repeat questions awaiting answers.

---

## Question Bank

- Easy change → simplicity: What could disappear while the requirements still hold?

- Safe change → compatibility: Which existing caller would behave differently?

- Useful communication → prior knowledge: What does the reader already know, and what must be explained?
