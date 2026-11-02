---
name: atlas-project
description: Project the intended system model into a work decomposition reconciled with the current system.
---

# Atlas Project

## Artifact (Output)

_State the intended properties declaratively._

- **Decomposition:** Revised nodes, attributes, and decomposition edges with the properties defined in @../cartographer/SKILL.md.

---

## Observation (Input)

_State the input categories and their roles._

- **System model:** Intended outcomes and constraints to project.

- **Atlas:** Existing nodes, attributes, edges, and history to reconcile.

- **Information:** Current system state, execution results, and decisions.

- **Domain:** Nodes we may create or update.

---

## Abduction

_Devise an explanation for observations._

- Map intended outcomes to existing nodes and propose additions, corrections, and removals.

- Propose decomposition edges whose children collectively cover their parent's work.

- Surface findings that require revising the intended system model.

---

## Deduction

_Derive consequences of the explanation._

- Check that each intended outcome has proposed work and each proposed node contributes to an outcome.

- Derive effects on active work, parent outcomes, and references to changed nodes.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Coordinate changes to active work with its owners.

- Apply revisions within the domain and verify coverage, references, and decomposition edges.

  - Preserve identities, ownership, history, and external relationships.

- Give a fresh reader the node and its references.

  - Check that they can reconstruct the assignment and acceptance checks.

- Retain unresolved discrepancies.
