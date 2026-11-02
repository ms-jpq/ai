---
name: cartographer
description: Revise a persistent graph of work and dependencies to cover the changes from the current system to the intended system.
---

# Cartographer

- Work graph (atlas):

  - Nodes:

    - Attributes include completion state and work category.

  - Edges:

    - **Decomposition edges** describe what work belongs within other work.

    - **Ordering edges** describe what work must precede other work.

      - The concurrent **execution frontier** contains selected nodes with satisfied ordering constraints.

    - A decomposition edge does not by itself imply an ordering edge.

  - Domain:

    - The subset of nodes we may create or update.

    - Relationships may extend beyond this subset.

- `work graph + information → revised work graph`.

  0. Develop and simplify the intended system model independently of the work graph.

  1. Reconcile work-graph nodes with the model and existing work, updating their attributes.

     - Project the intended system model into the work graph.

  2. Maximize the concurrent execution frontier by removing unnecessary sequencing and revising work boundaries.

  3. Derive views and clusters from node attributes and relationships.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Nodes:** Work needed to reach the intended system, with current attributes and enough context to execute and verify it.

- **Decomposition edges:** Children collectively cover their parent's work, including integration and verification.

- **Ordering edges:** Necessary prerequisites with explicit release conditions.

- **Views:** Selections, clusters, and progress measures derived from the graph.

---

## Observation (Input)

_State the input categories and their roles._

- **Atlas:** Existing work, relationships, attributes, and history to revise.

- **System model:** Intended behaviour and constraints that define what the work must achieve.

- **Evidence:** Current system state, execution results, and decisions that establish needed work.

- **Domain:** Nodes we may create or update.

---

## Abduction

_Devise an explanation for observations._

- Propose a projection of the intended system model into nodes, reconciling it with existing work and current evidence.

- Propose decomposition edges whose child outcomes combine into the parent outcome.

- Propose ordering edges and release conditions for starting, reviewing, and integrating work.

- Propose splits, merges, and removal of unnecessary sequencing to widen the execution frontier.

- Propose views and clusters from attributes and relationships.

- Refer challenges to the intended design back to the independently maintained system model.

---

## Deduction

_Derive consequences of the explanation._

- Trace each intended outcome to the proposed nodes and check how child outcomes combine.

- Derive the execution frontier from selected nodes, their states, and ordering constraints, including external prerequisites.

- Trace revisions through active work, ownership, dependants, and domain boundaries.

- State what a fresh reader must recover from each node and its references to carry out and check the work.

- Predict view membership and progress totals from the proposed attributes and relationships.

  - Account for completion, reopening, scope changes, and splits or merges.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Coordinate revisions with owners of active work and record how their assignments change.

- Verify completed work before relying on it as a prerequisite. Preserve its closure history when reopening it or adding follow-up work.

- Apply revisions within the domain, preserving identities, history, and external relationships.

- Check the projection in both directions: intended outcomes have work and acceptance checks, and nodes contribute to those outcomes.

- Check that child outcomes cover their parent and ordering edges have justified release conditions.

- Give a fresh reader only the node and its references.

  - Compare their reconstructed assignment with the source requirements and repair missing context where it belongs.

- Check ordering edges for blocking cycles and recompute the execution frontier.

- Generate views and clusters from the revised graph and check them against the predicted membership and totals.

  - Separate scope changes from completion in progress views.

- Retain unresolved discrepancies and revisit affected operations when evidence or the intended system changes.

---

## Graph Representation

- In a ticketing system:

  - Tickets represent nodes.

  - Dependencies represent ordering edges.

  - Projects and milestones represent derived clusters.

  - Statuses and labels represent node attributes.

  - Parent–child relationships represent decomposition edges.

---

## Operations

- **Converge:** Develop and simplify the intended system model into a minimal sufficient basis.

  - @../converge/SKILL.md

- **Project:** Project the intended system model into the atlas and reconcile existing work.

  - @../atlas-project/SKILL.md

- **View:** Derive views and clusters from the atlas.

  - @../atlas-view/SKILL.md

- **Dispatch:** Spawn agents along the execution frontier and record their assignments.

  - @../atlas-dispatch/SKILL.md
