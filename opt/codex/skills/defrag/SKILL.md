---
name: defrag
description: Establish canonical homes for related elements, consolidating scattered material and relocating misplaced elements.
---

# Defrag

- Obtain agreement before changing required behaviour or contracts.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Canonical homes:** Locations where related elements are consolidated.

- **References:** Links and uses updated to resolve to those homes.

---

## Observation (Input)

_State the input categories and their roles._

- **Elements:** Code, prose, configuration, or instructions to organize.

- **Organization:** Existing homes, responsibilities, and relationships that guide placement.

- **Uses:** Readers, callers, and references affected by relocation or consolidation.

- **Constraints:** Meaning and behaviour that consolidation must preserve.

---

## Abduction

_Devise an explanation for observations._

- Identify scattered or misplaced elements, competing homes, semantic duplicates, and unresolved aliases.

  - Exclude runtime state and generated output unless they are explicitly in scope.

- Choose or construct a canonical home for each concern.

  - Place related elements under a shared parent.

    - For example, declarations in a namespace or supporting bullets beneath a shared point.

  - Map misplaced elements to their proposed homes and identify affected references.

- Propose consolidating semantic duplicates: elements with equivalent meaning or behaviour under the same scope and conditions.

  - Retain candidates whose equivalence is unresolved.

- Propose one canonical term per confirmed alias set.

---

## Deduction

_Derive consequences of the explanation._

- Predict which related elements can be read or changed together in each proposed home.

- Derive reference updates for each move, including consumers of the old locations.

- Derive what each proposed consolidation must preserve for every original use.

- Identify which uses each term change affects and which distinct meanings it must preserve.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Establish the homes, move misplaced elements, and consolidate duplicates and confirmed aliases.

- Check that elements are in their intended homes and references resolve to them.

- Check that consolidation reduces fragmentation and preserves meaning and behaviour.

---

- Use @../op-purpose-formation/SKILL.md when the purpose or what must be preserved is unclear.

- Use @../op-problem-framing/SKILL.md when the consequences of fragmentation or their priorities are unclear.

- Use @../op-conceptual-synthesis/SKILL.md when inconsistent terms obscure shared meanings or necessary distinctions.

- Use @../refine/SKILL.md when prose remains unclear after consolidation.

- Use @../refactor/SKILL.md when consolidation requires reorganizing responsibilities or flows.
