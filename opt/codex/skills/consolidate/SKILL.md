---
name: consolidate
description: Select the strongest solution and incorporate useful contributions from alternatives into a coherent whole.
---

# Consolidate

- Combine the strongest design with useful contributions from alternatives, including implementation ideas, tests, documentation, and discovered constraints.

- Judge coherence, simplicity, and tradeoffs alongside behavioural verification. Passing tests does not establish design superiority.

## Invocation

- Run only when explicitly invoked for a bounded task. The current agent coordinates candidates, comparison, integration, and iteration.

- Use at least two independent implementers and exactly one independent reviewer, excluding the coordinator. Children do not delegate, and the reviewer does not implement a candidate.

- Check capacity, permissions, and isolation. Schedule independent children sequentially when only concurrency is limited, or stop if the required roles cannot be supported.

## Artifact (Output)

- One coherent solution incorporating useful contributions from the alternatives, with reconciled behavioural coverage and independent review of the integrated result.

## Observation (Input)

- Establish the shared purpose, requirements, authorized changes, compatibility obligations, scope, and baseline evidence.

- Snapshot the exact starting state, including staged, unstaged, relevant untracked or ignored changes, file modes, symlinks, and deletions.

- Preserve the original working tree and index without resetting, stashing, or committing user changes for convenience.

- Give implementers identical inputs and separate workspaces verified against that snapshot, isolating writable outputs, test data, and external resources from peers and production.

## Abduction

_Devise an explanation for observations._

- Develop materially different candidate designs, including one questioning a significant assumption, without sharing peer proposals, patches, reasoning, or results before candidates are frozen.

- Keep the baseline eligible. Cosmetic variants, deliberately incomplete alternatives, and candidates using the same approach do not supply the required comparison.

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

- Give the reviewer the frozen candidates, shared inputs, predictions, test cases, and reproducible commands and results without signalling a preferred winner.

- Reconcile useful behavioural tests from all candidates with the baseline suite without treating candidate-specific internals as shared requirements.

- Adapt harness bindings while preserving equivalent behavioural expectations across candidates. Resolve conflicting expectations from requirements and contracts, not votes.

- Inspect deleted assertions, skips, and weakened coverage. Change expectations only for authorized requirement changes while preserving coverage of remaining obligations.

- Run common tests against every candidate and the baseline in comparable isolated conditions, recording actual commands, environment, failures, and unrun checks separately from implementer claims.

- Let the reviewer request experiments or reject every candidate, judging design quality alongside correctness, compatibility, and operational cost.

- Retain the baseline when change has no supported benefit, or integrate the selected foundation and compatible contributions rather than mechanically merging architectures.

- Compare the destination with the snapshot before integration and preserve intervening user edits.

- Run the common suite and project checks on the integrated result, then independently review its design. Treat substantive hybrids or repairs as new candidates.

- Continue only for a concrete unresolved question and an observation or comparison that could resolve it.

- Start each cycle from a shared exact baseline without exchanging peer solution histories or allowing authors to review their own candidates.

- Complete when the integrated result passes checks and independent review finds no supported improvement within scope. Earlier review applies only if the examined design and behaviour remain unchanged.

- Stop inconclusively after two cycles without progress on the same question, or earlier at resource, permission, or task-budget limits.

- Treat missing comparisons, untested improvements, and unavailable checks as uncertainty, not proof of necessity. Extra compute does not expand scope or justify arbitrary alternatives.

- Resolve routine questions among agents, asking the user only for genuine product or constraint choices or additional permission.

- Keep comparison records temporary and report the selected design, useful contributions, verification, and limitations rather than debate transcripts.
