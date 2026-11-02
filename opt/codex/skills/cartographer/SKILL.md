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

    - A decomposition edge does not by itself imply an ordering edge.

  - Domain:

    - The subset of nodes we may create or update.

    - Relationships may extend beyond this subset.

  - View:

    - The concurrent **execution frontier** contains selected nodes with satisfied ordering constraints.

    - Clustering groups nodes by attributes and relationships.

- `work graph + information → revised work graph`.

  0. Develop and simplify the intended system model independently of the work graph.

  1. Project the intended system model into nodes, attributes, and decomposition edges, reconciling them with the current system.

  2. Recompose work boundaries and ordering dependencies to maximize the concurrent execution frontier.

  3. Derive views, including the execution frontier and clusters, from node attributes and edges.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Nodes:** Consistent with the intended and current system.

- **Decomposition edges:** Children collectively cover their parent's work.

- **Ordering edges:** Simplified to only necessary prerequisites with explicit release conditions.

- **Views:** Reproducible queries or scripts over the graph.

---

## Observation (Input)

_State the input categories and their roles._

- **Atlas:** Existing nodes, attributes, edges, and history to revise.

- **System model:** Intended behaviour and constraints that define what the work must achieve.

- **Information:** Current system state, execution results, and decisions.

- **Domain:** Nodes we may create or update.

---

## Operations

- **Converge:** Seek the simplest system model sufficient for its purpose, reasoning through revisions toward a stable fixed point.

  - @../converge/SKILL.md

- **Project:** Project the intended system model into a work decomposition reconciled with the current system.

  - @../atlas-project/SKILL.md

- **Recompose:** Recompose work and its ordering to maximize the concurrent execution frontier.

  - @../atlas-recompose/SKILL.md

- **View:** Build reproducible queries or scripts that derive views from an atlas.

  - @../atlas-view/SKILL.md

- **Dispatch:** Spawn agents on unclaimed atlas nodes along the execution frontier and record their assignments.

  - @../atlas-dispatch/SKILL.md

---

## Graph Representation

- In a ticketing system:

  - Tickets represent nodes.

  - Dependencies represent ordering edges.

  - Projects and milestones represent derived clusters.

  - Statuses and labels represent node attributes.

  - Parent–child relationships represent decomposition edges.
