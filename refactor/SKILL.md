---
description: Iterative code refactor. Architecture and control flow over surface syntax. Standards conformance over bespoke shapes.
---

# Loop

A cycle. Each pass: audit, propose, apply, audit again. Stop when the user signs off, or when further iteration is churn.

# Principles

In rough priority order. The first three are architectural and worth dragging the design back to; the last few are tactical.

## 1. Linearize and pipeline

The program flows in one direction. Each stage takes the previous stage's output, transforms it, and passes it on. Effects happen only at the final stage.

- Decompose along stage boundaries. Each stage is one transform.
- Persistent state lives at stage boundaries — files, queues, in-memory arrays — not inside stage logic.
- A stage that aggregates + renders + traverses + emits is doing four things; pull three of them out.
- The terminal stage (write, send, mutate external) should be a pure walk over fully-prepared data. If the consumer has to compute anything non-trivial, the producer didn't do its job.
- Effects deferred = errors deferred. Side-effects at the boundary, data through the middle.

## 2. Simple control flow

Cleverness in control flow is the most expensive kind. Flatten where possible.

- One predicate per branch. No `seen.has(x) || !seen.add(x)`-style side-effects smuggled past short-circuits when an `if (seen.has(x)) continue; seen.add(x)` reads cleaner.
- Early `continue` / `return` over nested `if`. The exception is a stable cascade with a clear shape (filter input, filter output, fallthrough).
- Replace `if/else` chains with a `switch` when the discriminator is a real enum and the cases are parallel.
- Don't compute values that are derived from other computed values. Pull the source of truth up.
- Mutation is fine in a tight scope (loop accumulator). Don't leak mutation across function boundaries.

## 3. Domain-driven types

Types model the domain. The shape of the data is the shape of the program.

- One stage, one type. The intermediate after stage N is its own named type, not an inline structural shape.
- Named subtypes over inline structural unions. If the same union appears in three places, give it a name; if subtypes share fields, lift them into a base.
- Discriminate by a property the runtime can actually check. If structural narrowing fails (e.g., `0 | number` collapses to `number`), write a type predicate.
- A type's fields exist for the program to read. If a field is "internal scaffolding" used only during construction, it usually wants to be a separate intermediate type or a parallel tree.

## 4. Move work to the right stage

The producer of data should compute everything the consumer needs. The consumer reads.

- Aggregates the consumer would otherwise compute by re-walking → compute once at construction, attach to the node.
- Decisions about output (names, kinds, attributes) are decisions about the data. If the data structure can carry them, it should.
- Predicates should read from contracts the producer already established, not re-derive from raw inputs. If the producer set a flag, read the flag.
- Effects (side-effecting calls, setters) live at the very end. Everything before is data.

## 5. Standards conformance

When the output targets a published spec, audit against the spec attribute-by-attribute. Don't invent shapes.

- Read the actual schema files. Don't trust documentation summaries.
- Required fields — set them. Recommended fields — set them when the data is available. Don't pretend a field exists if you can't fill it correctly.
- Hierarchy and relationships matter. If the spec says X is a sibling of Y, don't nest it under Y because the data happens to flow that way.
- Cite the spec by name when proposing changes. The argument is "the spec says X," not "I think X."

## 6. Real-duplication helpers

When the same _shape_ repeats with varying _values_, extract a helper. Don't extract for visual similarity alone.

- 3+ call sites with identical structural skeleton → helper.
- Helper signature should expose what varies, hide what doesn't.
- A helper used once is just a name. Use it if the name clarifies; otherwise inline.
- Reach for object-param helpers when 3+ args. Call sites become self-documenting.

## 7. Naming over positional access

A program reads top-to-bottom. Names compose; positions don't.

- Destructure tuples on the way in. `[a, b] = pair` over `pair[0]`, `pair[1]`.
- Object-param style at 3+ arguments. Positional style at 1 or 2.
- When `find` / `filter` results feed further accesses, write a typed predicate so the result narrows.
- Re-derivation is the worst kind of unnamed access. If a value already lives somewhere, read it; don't recompute it.

## 8. Skip surface nits

Things this skill does not propose:

- Whitespace, semicolon, quote-style, import-order — formatter's job.
- Renames where the existing name is fine.
- Pure style swaps (`match` over `switch`, `??` over `||`) unless invited.
- Performance micro-optimization absent a measured problem.
- Backwards-compatibility hacks for code paths the codebase doesn't have.

# Propose

- Surface 3–5 items per audit, ranked by payoff.
- Each item: one-paragraph description, file:line citation, sketch of the diff.
- Tag each as **clear win**, **judgment call**, or **style**. The user picks a subset.
- Don't auto-apply. Wait for an explicit subset.

# Apply

- Make the requested changes. Run the project's verification (type-check, lint, tests) after each batch.
- For substantial structural changes, enter plan mode first, write a plan file, get explicit approval, then apply.
- After applying, re-audit. New patterns become visible after the obvious ones are gone.

# Pace

- A single proposal message can hold 3–5 items. The user picks "do all" / "do 1 and 3" / "skip".
- Don't ask "are we happy?" after every edit. Ask after a meaningful pass — a structural change, a conformance audit, a consolidation round.
- "Anything else to clean up?" is the natural checkpoint after a few passes have settled.

# Tone

- Bullets, not prose.
- Cite specs by name when the basis is conformance.
- Rank, don't editorialize. The user knows what they value.
- When the proposal is wrong, the user will say. Take the redirection as data, not as a defeat.

# Args

- `auto` — skip the propose-and-wait step. Apply the highest-payoff item each pass. Stop when the next item is style-only.
