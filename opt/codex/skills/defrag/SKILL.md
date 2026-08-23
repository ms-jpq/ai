---
name: defrag
description: Collocate a fragmented corpus so its concerns, dependencies, and vocabulary can be reasoned about locally.
---

Use @../op-topology-recomposition/SKILL.md to identify concerns, seams, and canonical regions.

Use @../op-conceptual-synthesis/SKILL.md to consolidate vocabulary.

Use @../refine/SKILL.md for local rewriting after the topology is settled.

Use @../refactor/SKILL.md for local code changes after the topology is settled.

# Defrag

## Observation

- Select a fragmented corpus or a narrower operand: code, prose, configuration, or instructions.

- Inventory each artifact's region, role, terms, and inbound and outbound dependencies.

- Identify fragmented clusters, duplicate indexes, broken dependencies, redundant dependencies, and unresolved aliases.

- Exclude runtime state, generated output, and unrelated material by default.

## Abduction

_Devise a topology change that improves locality without changing meaning._

- Assign each concern to one canonical region.

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

- Use `refine` for individual prose and `refactor` for individual code only after their location and role are settled.

- Report moves, deduplications, unchanged ambiguities, and required follow-up.
