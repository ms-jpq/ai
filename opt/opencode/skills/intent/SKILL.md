---
name: intent
description: Make the implicit explicit. Write it down.
---

Use @../systems-thinking/SKILL.md.

# Intent

- Treat the user's request as evidence of intent, not a complete specification.

- Preserve the user's freedom to discover or change the goal. Do not turn a provisional preference into a constraint merely because it was stated first.

- Give each coherent topic one canonical intent model at `.notes/<topic>/INTENT.md`. Create the topic and its intent document before work that needs a shared direction; update it whenever that direction changes.

- Use `.notes/INTENT.md` only for direction that genuinely spans topics. A topic intent extends that root intent; it does not silently override it.

- Treat the applicable topic intent, together with any root intent, as the fixed point for work within that topic:

  - Read it before planning, implementing, or evaluating work.

  - Use it to decide whether a proposed action aligns with the current direction, needs more information, or should revise the direction.

  - On a conflict between root and topic intent, surface it. Revise the root or record an explicit, user-approved exception in the topic intent.

  - Do not recreate its contents in plans or task notes. Link to it and record only the local decision.

  - Keep it independent of any particular implementation so it remains useful as the work changes shape.

## Model

- Frame the problem, motivation, constraints, uncertainties, assumptions, approach, and generalization as prescribed by systems-thinking.

- State each item as a claim with its evidence, unknowns, and revision trigger.

- Distinguish explicitly:

  - Desired outcome: the change the user wants in the world.

  - Acceptance signals: observations that would make the user call it successful.

  - Current strategy: a replaceable way to pursue the outcome.

  - Commitments: decisions that become expensive to reverse.

  - Open questions: unknowns consequential enough to change the outcome, strategy, or commitments.

  - Directives: guidance for choices made under uncertainty. Mark each as fixed, strongly advised, or negotiable.

    - Fixed directives require an explicit user revision.

    - Strongly advised directives are the default; depart only with a stated reason and an intent-model update when the departure changes the direction.

    - Negotiable directives name a preference and the tradeoff that could justify changing it.

- Record contradictions rather than smoothing them over. Resolve them by revising the model with the user.

- Keep the document cohesive and short. It is high-level direction, not a plan, task log, or implementation design.

## Pair

- Alternate between synthesis and inquiry.

  - Synthesize the current model in compact, concrete language.

  - Ask one question that most reduces consequential uncertainty, unless a reversible action would reveal the answer more cheaply.

- Offer distinct paths when they imply materially different outcomes or tradeoffs. Name the tradeoff; do not manufacture choices where none exist.

- Separate observation, inference, and proposal. Mark model inferences as provisional.

- Test the current framing against a boundary alternative. Prefer the framing with less residual complexity, or record why the broader boundary is not worthwhile.

## Act

- Move work forward with reversible, independently verifiable actions when they do not constrain an unresolved consequential choice.

- Pause before irreversible action, external commitment, or work whose value depends on an unanswered open question.

- Re-check the model after evidence, user feedback, or a failed assumption. The implementation is allowed to change; the intent model is the thing being converged.

- When an action conflicts with the model, stop and either revise the action or surface the conflict to the user. Do not quietly make the document agree with the action.

## Hand off

- Before declaring convergence, state the current desired outcome, acceptance signals, constraints, commitments, unresolved questions, and next action.

- Call the model sufficient for the present action, not final. Continue co-evolving it until the user ends or redirects the work.
