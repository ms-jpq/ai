---
name: brief
description: Gather and distil outstanding questions into a structured decision brief that minimises the user's answering effort.
---

# Brief

## Artifact (Output)

- A structured decision brief whose answers resolve the outstanding decisions with minimal answering effort.

---

## Observation (Input)

- Gather outstanding questions from the conversation and documents in scope.

- Read available evidence and prior resolutions, including the conditions under which they hold.

---

## Abduction

_Devise an explanation for observations._

- Propose which questions need user input and which available evidence or prior answers already resolve.

- Merge semantic duplicates: questions about the same decision under the same conditions.

- Use `../op-conceptual-synthesis/SKILL.md` to unify terminology while preserving distinct decisions.

- Use `../op-topology-recomposition/SKILL.md` to put prerequisite decisions first and mark conditional follow-ups.

- Retain enough questions to resolve every decision that still matters.

- Keep independent decisions separate when combining them would make answering harder.

---

## Deduction

_Derive consequences of the explanation._

- Account for each original question: retained, answered by evidence, implied by another answer, or irrelevant for a stated reason.

- Derive which decisions each possible answer would resolve and which follow-ups would remain necessary.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply `../refine/SKILL.md` to question and option wording.

- Compare the refined set with the original questions and evidence. Restore missing decisions, conditions, or viable choices.

- As answers arrive or new questions arise, apply existing resolutions and their implications before asking again. Remove resolved follow-ups and revise those still needed.

- Reconsider prior resolutions when their conditions change or evidence conflicts.

---

## Presentation

- Give each question a unique, stable decision label and only the context needed to answer it.

- Explain what each option changes and whether to choose one or several.

- Use free text when predefined choices would distort the question.

- Present the prepared set together in the format below, marking conditional questions.

- Assign option emoji in reverse-rainbow order: 📘📗📒📙📕.

```markdown
# 📋 User Input: <Topic>

## 📚 <Decision Label>

<Question and necessary context>.

- 📘 _Option Label_: <Consequence>.

- 📗 _Option Label_: <Consequence>.
```
