---
name: atlas-project
description: Project an intended system model into an existing atlas, reconciling work nodes, attributes, and edges with the current system.
---

# Atlas Project

## Artifact (Output)

_State the intended properties declaratively._

- **Atlas:** Revised nodes and edges with the properties defined in @../cartographer/SKILL.md.

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

- Propose decomposition and ordering changes that cover the work and widen the execution frontier.

- Surface findings that require revising the intended system model.

---

## Deduction

_Derive consequences of the explanation._

- Check that each intended outcome has proposed work and each proposed node contributes to an outcome.

- Derive effects on active work, parent outcomes, dependants, and the execution frontier.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Coordinate changes to active work with its owners.

- Apply revisions within the domain and verify coverage, references, and both edge types.

  - Preserve identities, ownership, history, and external relationships.

- Check dependency release conditions and ordering edges for blocking cycles.

- Give a fresh reader the node and its references.

  - Check that they can reconstruct the assignment and acceptance checks.

- Retain unresolved discrepancies.

---

- Use @../atlas-view/SKILL.md to refresh views affected by node or edge changes.
