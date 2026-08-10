---
name: op-topology-modeling
description: Model dependency topology by making concerns, boundaries, directed dependencies, placement, and execution order explicit.
---

# Topology Modeling

Keep the model in `.notes/`.

## Map

- Identify the concerns that make up the current system.

  - Give each concern an explicit boundary.

- Draw the dependency topology.

  - Nodes: concerns.

  - Directed edges: dependencies.

  - Placement: where each concern and its required context currently lives.

- Identify cycles, hidden dependencies, and accidental distance between related concerns.

- Derive an execution order by topologically sorting the graph.

  - Record cycles as unresolved ordering constraints; a cyclic graph has no complete topological order.

- Update the topology whenever later evidence contradicts a node, edge, boundary, or placement.

## Hand Off

- Give topology reshaping the current graph, its ordering constraints, and the evidence behind each edge.

- Keep the model sufficient for the next decision. Do not inventory the universe.
