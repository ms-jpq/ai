---
name: defrag
description: Collocate a fragmented corpus without changing its design.
---

# Defrag

_A semantics-preserving maintenance pass._

Use @../op-problem-framing/SKILL.md to frame the corpus's fragmentation problems and rank their concerns.

Use @../op-conceptual-synthesis/SKILL.md to consolidate vocabulary.

Use @../refine/SKILL.md for local rewriting after the topology is settled.

Escalate to @../refactor/SKILL.md when a required fix changes responsibilities, contracts, or flows.

## Observation

- Select a fragmented corpus or a narrower operand: code, prose, configuration, or instructions.

- Inventory each artifact's region, role, terms, and inbound and outbound dependencies.

- Identify fragmented clusters, duplicate indexes, broken dependencies, redundant dependencies, and unresolved aliases.

- Exclude runtime state, generated output, and unrelated material by default.

## Abduction

_Devise a collocation that improves locality without changing the design._

- Do not reassign responsibilities, change contracts, or alter control or data flow.

- Assign each framed concern to one canonical region.

- Move one verified cluster at a time.

  - Resolve the destination and affected references before moving it.

  - Record each old-to-new path mapping.

- Deduplicate exact copies only.

  - Preserve non-identical material and unresolved alias candidates.

- Propose one canonical term per confirmed alias set.

  - Do not collapse distinct meanings or scopes.

## Deduction

_Derive consequences of the defragmentation hypothesis._

- Predict that each retained concern has one canonical region.

- Predict that every retained dependency resolves and no live dependency targets an old path.

- Predict that each approved alias set uses one canonical term within the affected cluster.

## Induction

_Test those consequences and provisionally retain or revise the topology._

- Verify the predicted regions, dependencies, and vocabulary after each cluster.

- Use `refine` for individual prose only after its location and role are settled.

- Escalate structural changes to `refactor`.

- Report moves, deduplications, unchanged ambiguities, and required follow-up.
