---
name: brief
description: Gather and distil outstanding questions into a structured decision brief that minimises the user's answering effort.
---

# Brief

## Prepare

- Gather outstanding questions from the conversation and documents in scope.

- Merge semantic duplicates: questions about the same decision under the same conditions.

- Resolve questions from available evidence, prior answers, and their implications before asking the user, including when new questions arise.

- Preserve the conditions of prior resolutions. Reconsider them when conditions change or evidence conflicts.

- Use `../op-conceptual-synthesis/SKILL.md` to unify terminology while preserving distinct decisions.

- Use `../op-topology-recomposition/SKILL.md` to put prerequisite decisions first and mark conditional follow-ups.

- Retain enough questions to resolve every decision that still matters.

- Keep independent decisions separate when combining them would make answering harder.

---

## Check

- Account for each original question: retained, answered by evidence, implied by another answer, or irrelevant for a stated reason.

- Check each answer branch for follow-ups that remain necessary.

- Apply `../refine/SKILL.md` to question and option wording.

- Recheck that the refined questions cover the original decisions and preserve viable choices.

---

## Present

- Give each question a unique, stable decision label and only the context needed to answer it.

- Explain what each option changes and whether to choose one or several.

- Use free text when predefined choices would distort the question.

- Present the prepared set together in the format below, marking conditional questions.

- As answers arrive, remove resolved follow-ups and revise those still needed.

- Assign option emoji in reverse-rainbow order: 📘📗📒📙📕.

```markdown
# 📋 User Input: <Topic>

## 📚 <Decision Label>

<Question and necessary context>.

- 📘 _Option Label_: <Consequence>.

- 📗 _Option Label_: <Consequence>.
```
