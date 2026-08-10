---
name: defrag
description: "Simplification: local reasoning. Method: collocation."
---

Use @../../skills/op-concern-decomposition/SKILL.md to identify concerns and seams.

Use @../../skills/op-concern-collocation/SKILL.md to establish canonical regions.

Use @../../skills/op-terminology-distillation/SKILL.md to consolidate vocabulary.

# Defrag

## Boundary

- Defragment an instruction corpus.

  - Organize instruction locations.

  - Repair instruction references.

  - Consolidate shared vocabulary.

- Use `refine` for an individual instruction.

  - Improve writing before or after compaction.

  - Do not turn defragmentation into a general rewriting pass.

## Scope

- Default to the workspace's instruction corpus.

  - Include rules.

  - Include hooks and hook implementations.

  - Include skills.

  - Include prompts and templates.

  - Include profiles and configuration.

  - Include instructional prose.

- Accept a narrower operand.

  - Accept an instruction file.

  - Accept an instruction directory.

  - Accept an instruction topic.

- Exclude unrelated material by default.

  - Exclude runtime state.

  - Exclude dependencies.

  - Exclude source artifacts.

  - Exclude generated output.

  - Exclude code unrelated to instructions.

## Scan

- Inventory each instruction.

  - Record its region.

  - Record its audience.

  - Record its function.

  - Record its core terms.

  - Record its inbound references.

  - Record its outbound references.

- Identify defects.

  - Identify fragmented clusters.

  - Identify exact duplicates.

  - Identify duplicate indexes.

  - Identify broken references.

  - Identify redundant references.

- Identify alias candidates.

  - Treat candidates as unresolved.

  - Treat non-identical material as distinct.

  - Do not infer authority from similarity.

## Defragment

- Place each instruction function in one canonical region.

  - Use the established instruction layout.

  - Propose a target when no local convention decides it.

- Move one verified cluster at a time.

  - Resolve the destination before moving it.

  - Resolve every affected reference before moving it.

  - Record each old-to-new path mapping.

- Repair references after each move.

  - Update Markdown links.

  - Update instruction includes.

  - Update hook registrations.

  - Update configuration paths.

- Deduplicate exact copies.

  - Record one canonical copy per set.

  - Remove duplicates only with explicit authorization.

  - Replace removed duplicates with links or references when needed.

- Preserve non-duplicate material.

  - Preserve content and provenance.

  - Do not rewrite, summarize, reconcile, discard, or reinterpret it.

## Compact

- Propose one canonical term per confirmed alias set.

  - List every occurrence.

  - State why the terms are equivalent.

- Confirm the canonical vocabulary before replacing aliases.

  - Do not collapse distinct scopes.

  - Do not collapse distinct meanings.

- Apply approved replacements consistently within the affected cluster.

## Verify

- Verify the result.

  - Verify every retained reference resolves.

  - Verify no live reference targets an old path.

  - Verify every alias set uses its approved canonical term.

  - Verify every removed duplicate has a canonical replacement.

- Report the result.

  - Report the operand.

  - Report instruction regions.

  - Report moves.

  - Report deduplications.

  - Report unchanged ambiguities.

  - Report required follow-up.
