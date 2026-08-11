---
name: op-topology-decomposition
description: Simplify flow across boundaries.
---

# Topology Decomposition

## Artifact

- A basis of named elements, each defined by an explicit boundary.

- Explicit flows between elements form the topology.

## Observation

- Select the affected concern topology; record its external boundaries and ordering constraints.

- Identify the concerns that make up the current system.

  - Give each concern an explicit boundary.

- Map the dependency topology.

  - Nodes: concerns.

  - Directed edges: dependencies.

  - Placement: where each concern and its required context currently lives.

- Identify cycles, hidden dependencies, and accidental distance between related concerns.

- Topologically sort the graph to derive an execution order.

  - Record cycles as unresolved ordering constraints; a cyclic graph has no complete topological order.

## Abduction

_Devise an explanation for observations._

- Reshape the topology where evidence exposes accidental coupling or distance.

  - Split an entangled concern.

  - Merge concerns that cannot be independently understood or verified.

  - Move or collocate the parts required for one local decision.

  - Remove an accidental dependency or make an unavoidable one explicit.

  - Reorder work from the dependency graph.

  - Integrate systems by merging their topologies and making their shared seams explicit.

- Preserve external contracts unless the topology model demonstrates they are wrong.

- Treat refactoring, modularization, and architecture as applications of this operation.

## Deduction

_Derive consequences of the explanation._

- State the expected effects on boundaries, dependencies, placement, and execution order.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Verify changed boundaries, dependencies, and the resulting execution order.

- Compare the proposed topology with the current one.

  - Count concepts, boundaries, dependencies, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Record retained dependencies and update the topology when evidence contradicts a node, edge, boundary, or placement.
