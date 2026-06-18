---
description: Iterative code refactor.
---

# Workflow

- Discover the invariants first. No invariants, can't refactor.

  - Behavior that must survive: contract, outputs, public surface.

  - Pin with tests. If none, write one capturing current behavior before touching anything.

- Each pass: audit → propose → apply → verify against invariants → re-audit. Stop on sign-off or churn.

- Propose 3–5 items/audit, ranked by payoff. Each: description, file:line, diff sketch, tag — **clear win** / **judgment call** / **style**.

- Don't auto-apply; wait for an explicit subset. `auto`: apply highest-payoff each pass, stop when next is style-only.

- Substantial structural change → create ./.notes/plans/\*.md file, approval, apply.

# Principles

## 1. Pipeline producers, thin consumers

- Producer computes everything; consumer reads. Effects only at the final stage — a pure walk over prepared data.

- Stage doing aggregate + render + traverse + emit → pull three out.

- Aggregate the consumer would re-walk → compute once at construction, attach to the node.

- Read the flag the producer set; don't re-derive from raw inputs.

## 2. Simple control flow

- One predicate per branch. `if (seen.has(x)) continue; seen.add(x)` over `seen.has(x) || !seen.add(x)`.

- Early `continue` / `return` over nested `if`. Exception: a stable cascade — filter input, filter output, fallthrough.

## 3. Domain-driven types

- One stage, one named type. Inline structural shapes = types not yet named.

- Named subtypes over inline unions; lift shared fields into a base.

- Discriminate on a runtime-checkable property. Structural narrowing fails (`0 | number` → `number`) → write a predicate.

- `find` / `filter` feeding further access → typed predicate so it narrows.

- Construction-only scaffolding → separate intermediate type or parallel tree.

## 4. Standards conformance

- Output targets a published spec → audit attribute-by-attribute; don't invent shapes.

- Read the schema files, not doc summaries.

- Preserve hierarchy: sibling in spec → sibling in code, regardless of data flow.

- Cite the spec by name — "the spec says X," not "I think X."

## 5. Real-duplication helpers

- Same shape, varying values → extract. Not for visual similarity alone.

- Signature exposes what varies, hides what doesn't. Object-param at 3+ args, positional at 1–2.

- Used once → just a name; inline unless the name clarifies.

# Out of scope

- Renames where the existing name is fine.

- Style swaps (`match` over `switch`, `??` over `||`) unless invited.

- Performance micro-optimization absent a measured problem.
