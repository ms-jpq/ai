---
name: defrag
description: Defragment a workspace's instructions.
---

# Defrag

## Scope

- Treat the workspace's instruction corpus as the default operand: rules, hooks and hook implementations, skills, agent prompts, prompt templates, profiles, configuration, and instructional prose. Accept an explicit instruction file, directory, or topic for a narrower pass.

- Exclude runtime state, dependencies, source artifacts, generated output, and code unrelated to instructions unless the user explicitly includes it.

## Scan

- Inventory each instruction's current region, audience, function, core terms, and inbound and outbound references.

- Identify fragmented instruction clusters, exact duplicates, duplicate indexes, broken or redundant references, and alias candidates: different terms that may name the same concept.

- Keep alias candidates separate from decisions. Similar wording does not establish equivalent meaning.

- Treat non-identical content as distinct. Do not infer which version is correct, current, or more important.

## Defragment

- Assign each instruction function one canonical contiguous region using the workspace's established instruction layout. Propose the target when no local convention decides it.

- Move one verified instruction cluster at a time. Know the destination and every affected reference before moving it.

- Update Markdown links, instruction includes, hook registrations, configuration paths, and other resolved references to each moved instruction. Record the old-to-new path mapping.

- Record one canonical copy for each set of exact duplicates. Remove a duplicate only with explicit authorization; replace it with a link or reference when the relationship matters.

- Preserve content and provenance. Do not rewrite, summarize, reconcile, discard, or reinterpret non-duplicate material.

## Compact

- Propose one canonical term for each confirmed alias set, with its occurrences and the reason the terms are equivalent.

- Confirm the canonical vocabulary before replacing aliases. Do not collapse terms with distinct scope or meaning.

- Apply approved replacements consistently within the affected instruction cluster.

## Verify

- Verify that every retained instruction reference resolves, every moved instruction has no live references to its old path, aliases have one approved canonical term, and each removed duplicate has a canonical replacement.

- Report the operand, instruction regions, moves, deduplications, unchanged ambiguities, and any required follow-up.
