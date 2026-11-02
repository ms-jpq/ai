---
name: tldr
description: Refocus a document on the user's current concerns, removing irrelevant or outdated content and adding missing information that matters.
---

# TLDR

## Artifact (Output)

_State the intended properties declaratively._

- **Document:** Current information addressing the user's concerns, with irrelevant detail removed and consequential omissions filled.

---

## Observation (Input)

_State the input categories and their roles._

- **Document:** The content to refocus.

- **Concerns:** What the user needs to understand, decide, or do.

- **Evidence:** Sources supporting corrections and additions.

---

## Abduction

_Devise an explanation for observations._

- Identify outdated claims, irrelevant detail, and consequential omissions.

- Propose what to retain, remove, replace, or add based on its relevance to the user's concerns.

  - Distinguish obsolete content from older information that still explains a current constraint or decision.

- Organize the document around what matters most now.

---

## Deduction

_Derive consequences of the explanation._

- Predict how each change helps the user understand, decide, or act.

- Check that proposed removals preserve necessary context, constraints, trade-offs, and uncertainty.

- Identify evidence needed to verify replacements and additions.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Verify proposed updates against the relevant sources, then revise the document.

- Check the result against the user's concerns for remaining distractions and consequential omissions.

  - Keep unresolved questions explicit.

---

- Use @../op-purpose-formation/SKILL.md when the user's concerns or the document's purpose are unclear.

- Use @../gap-analysis/SKILL.md to find missing information that affects the user's understanding, decisions, or actions.

- Use @../refine/SKILL.md to make the revised content concise and comprehensible.

- Use @../qs/SKILL.md when deciding what to retain, remove, or add requires user input that existing answers and evidence cannot resolve.
