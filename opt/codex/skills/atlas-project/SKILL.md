---
name: atlas-project
description: Project an intended system model into an existing atlas, reconciling work nodes, attributes, and edges with current evidence.
---

# Atlas Project

---

## Artifact (Output)

_State the intended properties declaratively._

- **Nodes:** Work needed to reach the intended system, with current attributes, source references, and acceptance checks.

- **Decomposition edges:** Children collectively cover their parent's work.

- **Ordering edges:** Necessary prerequisites with explicit release conditions.

---

## Observation (Input)

_State the input categories and their roles._

- **System model:** Intended outcomes and constraints to project.

- **Atlas:** Existing nodes, attributes, edges, and history to reconcile.

- **Evidence:** Current system state and decisions that establish needed work and node attributes.

- **Domain:** Nodes we may create or update.

---

## Abduction

_Devise an explanation for observations._

- Map intended outcomes to existing nodes and propose additions, corrections, and removals.

- Propose decomposition and ordering edges, keeping parent–child relationships distinct from execution order.

- Surface findings that require revising the intended system model.

---

## Deduction

_Derive consequences of the explanation._

- Check that each intended outcome has proposed work and each proposed node contributes to an outcome.

- Derive effects on active work, parent outcomes, dependants, and the execution frontier.

- Identify the evidence needed to justify attribute changes and dependency release.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Check proposed changes against the model and evidence, coordinating changes to active work with its owners.

- Apply revisions within the domain and verify coverage, references, and both edge types.

  - Preserve identities, ownership, history, and external relationships.

- Recompute the execution frontier and retain unresolved discrepancies.
