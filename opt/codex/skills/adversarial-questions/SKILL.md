---
name: adversarial-questions
description: Derive questions from a purpose and its concerns, building a reusable question bank through application and revision.
---

# Adversarial Questions

## Goals

- Derive useful questions through `purpose → concerns → questions`, without relying on the user's presence or objections.

- Build a reusable bank of concern-to-question mappings that improves through use.

- Help the caller address what matters to the purpose, not to prescribe solutions.

- Use @../op-purpose-formation/SKILL.md when the purpose needs clarification.

- Use @../op-problem-framing/SKILL.md to establish or revise the concerns and priorities from which questions are derived.

- Use @../gap-analysis/SKILL.md to discover missing concerns or gaps in question coverage relative to the purpose.

## Artifact (Output)

- Prioritized questions, each traceable to a concern and its motivating purpose, with that connection stated when not apparent.

- Reusable additions or revisions to the question bank when experience supports them.

## Observation (Input)

- Read the purpose, constraints, current situation, known concerns, and available evidence.

- Read the Question Bank below for candidate mappings, not a checklist to apply wholesale.

- Record what is already known or answered and what remains uncertain about achieving the purpose.

## Abduction

_Devise an explanation for observations._

- Propose what needs to be understood or decided about the framed concerns, using their priorities to focus the questions.

- Derive questions from consequential gaps and known concerns to help the caller address them. Missing coverage is not a prerequisite for questioning.

- Adapt relevant bank entries and generate questions where the bank provides no suitable mapping.

- Let the concern determine whether to ask about understanding, options, evidence, coordination, simplification, or another response.

## Deduction

_Derive consequences of the explanation._

- Predict how plausible answers would change understanding, a decision, or an action relevant to the concern.

- Identify what information would distinguish those answers and whether it is already available.

- Check whether the question still matters if the current implementation or proposed solution changes.

- Separate reusable questions arising from the concern from details specific to this situation.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test each proposed mapping against the stated purpose, actual situation, and available evidence.

- Remove answered, duplicate, or inconsequential questions and revise false premises or leading formulations.

- Return the remaining questions prioritized by concern and usefulness now, without supplying unestablished answers.

- When answers or changed work become available, check whether the questions helped address their concerns and revise the mappings accordingly.

- Retain useful mappings in the Question Bank with their motivating purposes, concerns, and applicability conditions.

- Retire a question for the current work when answered without discarding its reusable form or the underlying concern.

## Application

- Apply as work develops, including before action, after material changes, and before completion. A failure or suspected defect is not required.

- Direct questions to the working agent or caller, including yourself during self-review.

- The caller owns answers, experiments, implementation, and acceptance. The output is questions, not a readiness verdict or a required competing implementation.

- Involve the user only for unresolved requirements, tradeoffs they must choose, or additional permission. Question generation does not broaden scope or relax constraints.

- Return questions and necessary context, not the deliberation used to generate them. An empty result is valid when no useful question remains.

- Re-invoke `adversarial-questions` as work and evidence change, not to repeat questions awaiting answers.

## Question Bank

- Easy change → simplicity: What could disappear while the requirements still hold?

- Safe change → compatibility: Which existing caller would behave differently?

- Useful communication → prior knowledge: What does the reader already know, and what must be explained?
