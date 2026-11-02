---
name: defrag
description: Consolidate fragmented content and semantic duplicates while preserving meaning and behaviour.
---

# Defrag

- Use @../op-purpose-formation/SKILL.md when the purpose or what must be preserved is unclear.

- Use @../op-problem-framing/SKILL.md when the consequences of fragmentation or their priorities are unclear.

- Use @../op-conceptual-synthesis/SKILL.md when inconsistent terms obscure shared meanings or necessary distinctions.

- Use @../refine/SKILL.md when prose remains unclear after consolidation.

- Use @../refactor/SKILL.md when consolidation requires reorganizing responsibilities or flows.

- Obtain agreement before changing required behaviour or contracts.

---

## Artifact (Output)

_State the intended properties declaratively._

- Related content shares canonical locations, and references resolve to the retained content.

- Confirmed semantic duplicates have one retained form, and confirmed aliases have one canonical term.

  - Differences in scope, conditions, certainty, and required behaviour remain expressible.

- Meaning, responsibilities, contracts, and flows are preserved, with unresolved ambiguities explicit.

- Moved content remains traceable to its new location, with required follow-up explicit.

---

## Observation (Input)

_State the input categories and their roles._

- Code, prose, configuration, or instructions in scope: the content to consolidate.

  - Runtime state, generated output, and unrelated material are outside the scope by default.

- Existing locations, roles, terminology, and dependencies in both directions: context for choosing destinations and preserving uses.

- Required meaning, behaviour, responsibilities, contracts, and flows: constraints on consolidation.

---

## Abduction

_Devise an explanation for observations._

- Identify scattered related content, candidate semantic duplicates, broken or redundant references, and unresolved aliases.

- Propose a canonical location for each concern and explain how it reduces fragmentation.

  - Nest related elements under a shared parent to make their relationship explicit.

    - For example, declarations in a namespace or supporting bullets beneath a shared point.

  - Map each proposed move to its destination and affected references.

- Propose consolidation of semantic duplicates: equivalent meaning or behaviour under the same scope and conditions, regardless of wording or form.

  - Preserve differences in scope, conditions, certainty, and required behaviour.

  - Retain candidates whose equivalence is unresolved.

- Propose one canonical term per confirmed alias set.

  - Do not collapse distinct meanings or scopes.

---

## Deduction

_Derive consequences of the explanation._

- Identify which reads and edits the proposed placement brings together.

- Derive reference updates for each move, including consumers of the old locations.

- Derive what each proposed consolidation must preserve for every original use.

- Identify which uses each term change affects and which distinct meanings it must preserve.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply the proposed moves, deduplications, and confirmed term changes one cluster at a time.

- Check the resulting locations, references, and terms against the predictions.

- Retain a change only when it reduces fragmentation without changing preserved meaning or behaviour.

  - Remove duplicates only after checking the retained form against every original use.
