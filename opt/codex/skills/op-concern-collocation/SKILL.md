---
name: op-concern-collocation
description: Collocate the parts of one concern so it can be understood and changed locally.
---

# Concern Collocation

## Locate

- Select one concern from a current situation model or concern decomposition.

- Identify every part needed to understand, change, and verify it.

  - Definitions.

  - State and contracts.

  - Implementations and effects.

  - Tests, instructions, and references.

## Collocate

- Establish one canonical region for the concern.

- Move or link the identified parts until their relationship is locally visible.

- Keep cross-concern dependencies explicit at the boundary.

- Do not duplicate an authoritative definition to create apparent locality.

## Verify

- Verify that one bounded reading path explains the concern.

- Verify that every inbound reference resolves after a move.

- Record remaining remote dependencies and why they cannot be collocated.
