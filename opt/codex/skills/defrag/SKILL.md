---
name: defrag
description: A semantics-preserving maintenance pass.
---

# Defrag

Use @../op-purpose-formation/SKILL.md to establish the corpus's purpose and preservation boundary.

Use @../op-problem-framing/SKILL.md to frame the corpus's fragmentation problems and prioritize their concerns.

Use @../op-conceptual-synthesis/SKILL.md to consolidate vocabulary.

Use @../refine/SKILL.md for local rewriting after the topology is settled.

Escalate to @../refactor/SKILL.md when a required fix changes responsibilities, contracts, or flows.

## Artifact (Output)

- A collocated corpus with canonical regions, repaired references, and consolidated exact duplicates and confirmed aliases.

- Preserved meaning, responsibilities, contracts, and flows, with unresolved ambiguities explicit.

- Old-to-new path mappings, deduplications, and required follow-up.

## Observation (Input)

- Select a fragmented corpus or a narrower operand: code, prose, configuration, or instructions.

- Inventory each artifact's region, role, terms, and inbound and outbound dependencies.

- Identify fragmented clusters, duplicate indexes, broken dependencies, redundant dependencies, and unresolved aliases.

- Exclude runtime state, generated output, and unrelated material by default.

## Abduction

_Devise an explanation for observations._

- Propose one canonical region for each framed concern and explain how it reduces fragmentation.

- Map each proposed move to its destination and affected references.

- Propose deduplication of exact copies only.

  - Preserve non-identical material and unresolved alias candidates.

- Propose one canonical term per confirmed alias set.

  - Do not collapse distinct meanings or scopes.

## Deduction

_Derive consequences of the explanation._

- Derive which reads and edits become local under the proposed placement.

- Derive reference updates from the proposed moves, including consumers that depend on the old paths.

- Derive which uses must change under each proposed alias substitution and which distinct meanings must remain untouched.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply the proposed moves, deduplications, and confirmed term changes one cluster at a time.

- Verify the predicted regions, dependencies, and vocabulary after each cluster.

- Retain a change only when it reduces fragmentation without changing preserved meaning or behaviour.
