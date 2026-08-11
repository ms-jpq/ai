---
name: op-decision-basis-modeling
description: Redefine the option space.
---

# Decision-Basis Modeling

## Artifact

- A decision space for one decision.

  - The choice, intended outcome, authority, and invariants.

  - Viable options and the conditions that admit or rule out each one.

  - The evidence, assumptions, and uncertainties that distinguish those options.

## Observation

- Select one decision; state its choice, intended outcome, authority, and invariants.

- Identify its current options and the conditions that admit or rule out each one.

- Gather the evidence, assumptions, and uncertainties that can change which options are viable.

  - The user's request and conversation.

  - Notes, observed state, and other relevant artifacts.

  - Existing plans, implementation, constraints, and results.

## Abduction

_Devise an explanation for observations._

- Construct or revise the decision space.

  - Make the choice, options, admission conditions, and authority explicit.

  - Record the evidence, assumptions, constraints, invariants, and open questions that distinguish options.

  - State the update triggers that would change the decision space.

- Generate decision-relevant alternatives by varying assumptions, constraints, framing, and abstraction level.

  - Treat the current model and topology as variables rather than givens.

  - Recognize wider problem classes and import candidate structures, constraints, and solutions.

  - Include alternatives that improve the outcome while preserving invariants.

- State a policy or specification when an acceptable outcome must remain stable across later decisions.

## Deduction

_Derive consequences of the explanation._

- Derive the expected outcome of each viable option and the observations that distinguish it from plausible alternatives.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the expected outcomes against evidence and plausible alternatives; surface contradictions and uncertainty.

- Retain only evidence-supported options and conditions; update the decision space when direction or evidence changes.

- Treat the decision space as contextually closed only when no omitted relation can change viable options.
