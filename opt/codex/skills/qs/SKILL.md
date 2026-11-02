---
name: qs
description: Gather and distil outstanding questions into a structured decision brief that minimizes the user's answering effort.
---

# Questions

## Artifact (Output)

_State the intended properties declaratively._

- **Decision brief:** Questions whose answers resolve outstanding decisions with minimal answering effort.

- **Resolutions:** Recorded answers and their applicable conditions, retained outside the brief.

---

## Observation (Input)

_State the input categories and their roles._

- **Questions:** Outstanding decisions and the context needed to answer them.

- **Resolutions:** Prior answers and their applicable conditions.

---

## Abduction

_Devise an explanation for observations._

- Propose which questions need user input and which the context or prior answers resolve.

- Keep independent decisions separate when combining them would make answering harder.

---

## Deduction

_Derive consequences of the explanation._

- Account for each original question: retained, answered, implied by another answer, or irrelevant for a stated reason.

- Derive which decisions each possible answer would resolve and which follow-ups would remain necessary.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Compare the refined set with the original questions. Restore missing decisions, conditions, or viable choices.

- As answers arrive or new questions arise, apply existing resolutions and their implications before asking again.

  - Record resolutions and their applicable conditions in the relevant project documents or decision notes outside the brief.

  - Remove answered questions and resolved follow-ups once their resolutions are recorded, then revise those still needed.

  - Reconsider prior resolutions when their conditions change.

---

## Presentation

- Give each question a stable decision label and the context needed to answer it.

- Explain each option's benefits, costs, constraints, and uncertainties.

  - Compare options on the same dimensions using specific effects.

- State whether to choose one option or several.

  - Use free text when predefined choices would distort the question.

- Present the prepared set together in the format below, marking conditional questions.

  - Assign option emoji in reverse-rainbow order: 📘📗📒📙📕.

```markdown
# 🐸 User Input: <Topic>

## 📚 <Decision Label>

<Question and necessary context>.

- 📘 _<Concrete choice>_: <Benefit>. <Cost or limitation>.

- 📗 _<Concrete choice>_: <Benefit>. <Cost or limitation>.
```

---

- Use @../fold/SKILL.md to incorporate new questions and subsequent edits into the existing brief, preserving its presentation and stable decision labels.

- Use @../defrag/SKILL.md during abduction to consolidate scattered questions and semantic duplicates about the same decision under the same conditions.

- Use @../op-conceptual-synthesis/SKILL.md during abduction to unify terminology while preserving distinct decisions.

- Use @../op-topology-recomposition/SKILL.md during abduction to put prerequisite decisions first and mark conditional follow-ups.

- Use @../wat/SKILL.md during induction to explain each decision and its options' consequences in concrete terms.
