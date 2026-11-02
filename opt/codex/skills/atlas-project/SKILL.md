---
name: atlas-project
description: Project an intended system model into an existing atlas, reconciling work nodes, attributes, and edges with current evidence.
---

# Atlas Project

---

## Artifact (Output)

_State the intended properties declaratively._

- The atlas covers the intended system through work nodes with outcomes, source references, and acceptance checks.

- Decomposition edges account for parent outcomes. Ordering edges express necessary prerequisites and release conditions.

- Missing work is added, stale descriptions and attributes are corrected, and extraneous work is pruned within the domain.

- Node identities, ownership, history, and external relationships survive revision. Unresolved discrepancies remain explicit.

---

## Observation (Input)

_State the input categories and their roles._

- The independently maintained system model defines the outcomes and constraints to project.

- The existing atlas and its history provide the nodes and edges to reconcile.

- Current system evidence and decisions establish remaining work, completion state, and work category.

- The domain defines which nodes may be created or updated.

---

## Abduction

_Devise an explanation for observations._

- Map intended outcomes to existing nodes and propose additions, corrections, and removals.

- Propose decomposition and ordering edges, keeping parent–child relationships distinct from execution order.

- Surface findings that require revising the intended system model.

---

## Deduction

_Derive consequences of the explanation._

- Trace coverage in both directions between intended outcomes and proposed work.

- Derive effects on active work, parent outcomes, dependants, and the execution frontier.

- Identify the evidence needed to justify attribute changes and dependency release.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Check proposed changes against the model and evidence, coordinating changes to active work with its owners.

- Apply revisions within the domain and verify coverage, references, and both edge types.

- Recompute the execution frontier and retain unresolved discrepancies.
