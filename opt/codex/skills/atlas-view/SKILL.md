---
name: atlas-view
description: Derive views and clusters from atlas nodes, attributes, relationships, and history.
---

# Atlas View

## Artifact (Output)

_State the intended properties declaratively._

- **Views:** Selections, clusters, or progress measures that answer the reader's questions using atlas data.

---

## Observation (Input)

_State the input categories and their roles._

- **Atlas:** Nodes, attributes, edges, and history to represent.

- **Questions:** What the reader wants to learn about selected work.

- **Conventions:** Classification and display conventions that guide presentation.

---

## Abduction

_Devise an explanation for observations._

- Propose selections, grouping criteria, and measures that answer the reader's questions.

- Choose a representation that exposes the relevant relationships and state.

---

## Deduction

_Derive consequences of the explanation._

- Predict view membership, cluster membership, and totals from the selected criteria.

- Identify relationships hidden by filtering and outcomes that could be counted more than once.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Generate views from the atlas and compare membership, relationships, and totals with the predictions.

  - Preserve node identities and relationship meanings, indicating connections beyond the selection.

  - Distinguish completion from scope changes and count each outcome once.

- Apply selection and presentation changes to the views, preserving the source graph.

---

- Use @../mat/SKILL.md for tabular views.

- Use @../dot/SKILL.md for graph views.
