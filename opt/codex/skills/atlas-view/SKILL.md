---
name: atlas-view
description: Build reproducible queries or scripts that derive views from an atlas.
---

# Atlas View

## Artifact (Output)

_State the intended properties declaratively._

- **Views:** Reproducible queries or scripts answering the reader's questions about the atlas.

---

## Observation (Input)

_State the input categories and their roles._

- **Atlas:** Nodes, attributes, edges, and history to represent.

- **Selection:** Nodes included in the view.

- **Questions:** What the reader wants to learn about selected work.

- **Conventions:** Display conventions that guide presentation.

---

## Abduction

_Devise an explanation for observations._

- Propose selections, grouping criteria, and measures that answer the reader's questions.

- Choose a representation that exposes the relevant relationships and state.

---

## Deduction

_Derive consequences of the explanation._

- Predict membership and totals from the selected criteria.

  - Include prerequisites outside the selection when deriving the execution frontier.

- Identify relationships hidden by filtering and outcomes that could be counted more than once.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Implement and run the queries or scripts, comparing their results with the predictions.

  - Preserve node identities and relationship meanings, indicating connections beyond the selection.

  - Distinguish completion from scope changes and count each outcome once.

- Apply selection and presentation changes to the views, preserving the source graph.

---

- Use @../mat/SKILL.md for tabular views.

- Use @../dot/SKILL.md for graph views.
