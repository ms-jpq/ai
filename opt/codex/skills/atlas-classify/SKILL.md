---
name: atlas-classify
description: Establish meaningful categories and classify atlas nodes to support grouping and filtering.
---

# Atlas Classify

## Artifact (Output)

_State the intended properties declaratively._

- **Categories:** Named distinctions with explicit membership criteria.

- **Classification:** Node attributes consistently expressing those distinctions, with unresolved assignments explicit.

---

## Observation (Input)

_State the input categories and their roles._

- **Atlas:** Nodes, attributes, and relationships to classify.

- **Questions:** What readers need to distinguish, group, or filter.

- **Conventions:** Existing categories, meanings, and queries that depend on them.

- **Domain:** Nodes we may update.

---

## Abduction

_Devise an explanation for observations._

- Propose categories that capture the distinctions readers need, consolidating equivalent categories.

- Define membership criteria and whether categories are exclusive or may overlap.

  - Keep independent dimensions separate, such as completion state and work category.

- Propose assignments from node descriptions and current information.

---

## Deduction

_Derive consequences of the explanation._

- Derive which nodes each category includes and excludes, examining ambiguous cases.

- Trace category changes to affected assignments and queries.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply category and assignment changes within the domain, updating affected queries.

- Compare membership against the criteria and revise distinctions that produce inconsistent assignments or fail to answer the reader's questions.
