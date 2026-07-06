---
name: refactor
description: Iterative code refactor.
---

# Workflow

- Discover the invariants and constraints first.

- Pin with tests. If none, write ones capturing current behavior before touching anything.

# Principles

## Simplification

- Strategy: One predicate per branch.


## Pipeline producers, thin consumers

- Producer computes everything; consumer reads. Effects only at the final stage — a pure walk over prepared data.

- Stage doing aggregate + render + traverse + emit → pull three out.

- Aggregate the consumer would re-walk → compute once at construction, attach to the node.

- Read the flag the producer set; don't re-derive from raw inputs.

## Domain-driven types

- One stage, one named type. Inline structural shapes = types not yet named.

- Named subtypes over inline unions; lift shared fields into a base.

- Discriminate on a runtime-checkable property. Structural narrowing fails (`0 | number` → `number`) → write a predicate.

- `find` / `filter` feeding further access → typed predicate so it narrows.

- Construction-only scaffolding → separate intermediate type or parallel tree.

## Standards conformance

- Output targets a published spec → audit attribute-by-attribute; don't invent shapes.

- Read the schema files, not doc summaries.

- Preserve hierarchy: sibling in spec → sibling in code, regardless of data flow.

- Cite the spec by name — "the spec says X," not "I think X."

# Out of scope

- Renames, unless the existing name is semantically inaccurate.

- Style swaps.
