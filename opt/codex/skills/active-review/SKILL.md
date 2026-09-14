---
name: active-review
description: Review ongoing work against its goal, uncover and prioritize concerns, and ask probing questions that help the working agent revise its decisions.
---

# Active Review

_Review through questions as the work develops. The working agent owns the response and solution._

Use @../op-problem-framing/SKILL.md to extend or revise the shared problem frame when the work exposes missing concerns or inadequate priorities.

## Artifact (Output)

- Prioritized review questions grounded in observed work and the concerns they test.

  - Each question identifies the decision it could change and the evidence that would resolve it.

- Supported revisions to the shared problem frame, with resolved questions and remaining gaps explicit.

## Observation (Input)

- Read the caller's goal, constraints, and current problem frame, including its concerns and priorities.

- When invoked independently, recover these inputs from the task and existing work.

- Inspect current decisions, changes, and supporting evidence.

- Record which concerns the current work addresses and what remains unexplained.

## Abduction

_Devise an explanation for observations._

- Identify decisions whose justification or consequences remain unclear, and use them to uncover concerns the current work has missed.

- Prioritize uncovered and existing concerns by their consequences for the goal.

- Map each concern needing attention to a question whose answer could change the work.

  - Leave room for the current decision to be justified.

  - State a demonstrated defect directly instead of disguising it as a question.

## Deduction

_Derive consequences of the explanation._

- Identify how plausible answers would change the next decision.

- Derive observations that would distinguish a justified decision from the suspected gap.

- Drop questions already answered by the work or whose answers would not affect it.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Ask the working agent the question most likely to improve the next decision.

- Check its answer against the resulting work and evidence.

- Update the shared problem frame with newly supported concerns and priority changes.

- Close the question when evidence resolves it, or refine it when the gap remains. The concern may remain relevant.

- Ask the user when resolving the question requires a choice or permission they have not supplied.

## Recurring Questions

_Candidate questions, selected and adapted to the observed work._

- Simplicity: What requires this additional abstraction?

- Local reasoning: Could this decision live where its required information is already available?

- Compatibility: Which existing caller would behave differently?

- Verification: Would this test fail without the change?

- Prior art: What existing mechanism could address this concern?

## Iteration

- Re-invoke `active-review` as decisions, changes, and evidence develop.

- Let work proceed when no unresolved concern warrants a question.

- When reviewing your own work, answer from available evidence before interrupting the user.
