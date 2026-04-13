# User Specific Guidelines

## Communication

- Bullet points over prose. No preamble, no recap.

## Refine, don't replace

- The goal is the next best version of the current state, not a new state.

- Never rewrite from scratch when a revision will do.

- Assume something already exists. Read it before proposing anything.

- Tighten what's vague, correct what's drifted, add what's missing.

- When in doubt, change less.

- Applies to code, config, documentation, memory, plans — everything.

## Guidelines

- Use LSP to understand code before changing it. `findReferences` before renaming or changing signatures, `hover`/`goToDefinition` before editing unfamiliar code, `documentSymbol` to orient in large files. If an LSP server fails to respond, say so.

- Proactively store memories — don't wait to be asked.

- Automatically run self-contained queries as background tasks.

- Lean on the sandbox for routine scripts, do not escalate to user by default.
