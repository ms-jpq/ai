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

- When developing independent alternatives, keep peer proposals, patches, reasoning, and results separate until candidates are ready for comparison.

- Keep the baseline eligible. Do not manufacture differences or treat cosmetic variants as independent challenges to a design.

- Propose a foundation and explain why its design and tradeoffs best serve the purpose.

- Identify useful contributions from all alternatives, including rejected candidates, and explain how they fit the foundation without duplicating responsibilities or weakening contracts.

## Deduction

_Derive consequences of the explanation._

- Predict how the foundation and proposed contributions jointly satisfy requirements under normal, boundary, failure, and compatibility conditions.

- Predict interactions between contributions, including new state, dependencies, ordering constraints, caller knowledge, and maintenance obligations.

- Derive tests and design comparisons that could change the selection or expose an incompatible contribution.

- Have the reviewer challenge the highest-impact design claim, distinguishing testable predictions from qualitative preferences and tradeoffs.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Have the reviewer use Convergence on the candidate artifacts, shared inputs, predictions, and reproducible results without signalling a preferred winner.

- Reconcile useful behavioural tests from all candidates with the baseline suite without treating candidate-specific internals as shared requirements.

- Resolve conflicting test expectations from requirements and contracts, preserving equivalent behavioural obligations across candidates.

- Preserve required behavioural coverage unless an authorized requirement change makes it obsolete.

- Test candidates and the baseline under comparable conditions, distinguishing verified results from claims and unrun checks.

- Let the reviewer request experiments or reject every candidate, judging design quality alongside correctness, compatibility, and operational cost.

- Retain the baseline when change has no supported benefit, or integrate the selected foundation and compatible contributions rather than mechanically merging architectures.

- Preserve unrelated work and intervening user edits during integration.

- Run the common suite and project checks on the integrated result, then independently review its design. Treat substantive hybrids or repairs as new candidates.

- Continue only for a concrete unresolved question and an observation or comparison that could resolve it.

- Complete when the integrated result passes checks and independent review finds no supported improvement within scope. Earlier review applies only if the examined design and behaviour remain unchanged.

- Stop inconclusively when a material question cannot be resolved within available resources, permissions, or the task budget.

- Treat missing comparisons, untested improvements, and unavailable checks as uncertainty, not proof of necessity. Extra compute does not expand scope or justify arbitrary alternatives.

- Resolve routine questions among agents, asking the user only for genuine product or constraint choices or additional permission.

- Keep comparison records temporary and report the selected design, useful contributions, verification, and limitations rather than debate transcripts.
