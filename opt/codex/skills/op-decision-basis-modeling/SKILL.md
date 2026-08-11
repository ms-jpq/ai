---
name: op-decision-basis-modeling
description: Redefine the option space.
---

# Decision-Basis Modeling

## Artifact

- A contextually closed decision basis.

  - It includes every relation that can change viable options and excludes everything that cannot.

## Observation

- Select one decision; state its intended outcome and authority boundary.

- Record its current basis: reasons, assumptions, constraints, authority, invariants, and evidence.

- Gather relevant evidence.

  - The user's request and conversation.

  - Notes, observed state, and other relevant artifacts.

  - Existing plans, implementation, constraints, and results.

## Abduction

_Devise an explanation for observations._

- Model the current decision basis.

  - Outcome, constraints, authority, and actors.

  - Boundaries, interfaces, commitments, and open questions.

  - Explicit direction, inferences, and update triggers.

  - Invariants: constraints that every acceptable transformation must preserve.

- Generate decision-relevant alternatives by varying assumptions, constraints, framing, and abstraction level.

  - Treat the current model and topology as variables rather than givens.

  - Recognize wider problem classes and import candidate structures, constraints, and solutions.

  - Retain alternatives that improve the outcome while preserving invariants.

- Reframe, prioritize, and assess risk by revising the basis rather than treating its current shape as given.

- State a policy or specification when an acceptable outcome must remain stable across later decisions.

## Deduction

_Derive consequences of the explanation._

- State the observations that would distinguish the formulation from plausible alternatives.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Compare the decision basis with evidence and plausible alternatives; surface contradictions and uncertainty.

- Retain only the claims the evidence supports; update the basis as direction or evidence changes.

- Treat the model as sufficient for the decision, not final.
