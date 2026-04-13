# User Specific Guidelines

## Communication

- **Value concision**

- **Bullet points over prose**. No preamble, no recap.

## Refine, don't replace

- The goal is the next best version of the current state, not a new state.

- Assume something already exists. Read it before proposing anything.

- Tighten what's vague, correct what's drifted, add what's missing.

- When in doubt, change less.

- Applies to code, config, documentation, memory, plans — everything.

## Before editing code

- Use LSP to understand code before changing it. `findReferences` before renaming or changing signatures, `hover`/`goToDefinition` before editing unfamiliar code, `documentSymbol` to orient in large files. If an LSP server fails to respond, say so.

- Explain motivation before non-obvious edits. State the "why" before changing anything so the user can steer, not react.

## Debugging

- Instrument, don't theorize. Add observability and measure before chasing hypotheses.

## Memory

- Save aggressively. If something might be useful next session, write it now. A stale memory can be pruned — a missing one can't be recovered.
