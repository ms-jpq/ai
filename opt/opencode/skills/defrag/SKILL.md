---
name: defrag
description: Compact a workspace by reducing exact duplication and restoring a coherent layout without changing file meaning.
---

# Defrag

## Scope

- Take the workspace as the default operand. Accept an explicit file, directory, or topic when the user wants a narrower pass.

## Inspect

- Identify exact duplicate material, broken or redundant references, and artifacts whose location conflicts with the existing layout.

- Treat non-identical content as distinct. Do not infer which version is correct, current, or more important.

## Compact

- Record one canonical copy for each set of exact duplicates. Remove a duplicate only with explicit authorization; replace it with a link or reference when the relationship matters.

- Move artifacts only to satisfy an established local layout. Otherwise, leave their location unchanged and report the ambiguity.

- Preserve content and provenance. Do not rewrite, summarize, reconcile, discard, or reinterpret non-duplicate material.

## Verify

- Verify that every retained reference resolves and that each removed duplicate has a canonical replacement.

- Report the operand, moves, deduplications, unchanged ambiguities, and any required follow-up.
