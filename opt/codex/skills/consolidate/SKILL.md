---
name: consolidate
description: Select the strongest solution and incorporate useful contributions from alternatives into a coherent whole.
---

# Consolidate

- Combine the strongest design with useful contributions from alternatives, including implementation ideas, tests, documentation, and discovered constraints.

- Judge coherence, simplicity, and tradeoffs alongside behavioural verification. Passing tests does not establish design superiority.

- Use @../converge/SKILL.md to compare candidate designs and review the consolidated result against the system purpose, concerns, structure, concepts, and mechanisms.

## Invocation

- Work from available candidates. Develop independent alternatives when a consequential design question needs comparison.

- Assign independent review to an agent who did not author the candidate. Delegated work preserves the same information boundaries.

## Artifact (Output)

- One coherent solution incorporating useful contributions from the alternatives, with reconciled behavioural coverage and independent review of the integrated result.

## Observation (Input)

- Establish the shared purpose, requirements, authorized changes, compatibility obligations, scope, and baseline evidence.

- Compare candidates against shared requirements and baseline evidence.

## Abduction

_Devise an explanation for observations._

- Propose the candidate whose design best serves the shared purpose as the foundation, keeping the existing solution eligible.

- Identify contributions from the alternatives that could improve the foundation, and explain how they fit together.

- Explain which differences should remain alternatives rather than be combined.

## Deduction

_Derive consequences of the explanation._

- Predict how the proposed combination improves on the foundation while preserving required behaviour and compatibility.

- Derive the interactions and obligations introduced by combining contributions, including conflicts, duplication, and dependencies.

- Identify tests and design comparisons that could overturn the choice of foundation or a contribution's claimed benefit.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Integrate the proposed contributions while preserving unrelated work and required behavioural coverage.

- Test the combined result against the predictions and requirements, resolving conflicting expectations from shared contracts rather than candidate-specific internals.

- Have an independent reviewer use `converge` to assess the integrated design, including whether each contribution improves the whole enough to justify its added complexity.

- Retain useful contributions, revise or discard incompatible ones, and reconsider the foundation when the combination fails to serve the purpose.

- Verify the revised whole rather than relying on checks of its separate candidates.

- Report the consolidated result, consequential tradeoffs, verification, and unresolved limitations.
