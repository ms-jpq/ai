---
name: op-topology-decomposition
description: Model and decompose a system's concern topology to expose and reduce accidental dependencies. Use when boundaries, ordering, or placement resist local reasoning.
---

# Topology Decomposition

Keep the model in `.notes/`.

## Evidence

- Select the affected concern topology; record its external boundaries and ordering constraints.

- Identify the concerns that make up the current system.

  - Give each concern an explicit boundary.

- Map the dependency topology.

  - Nodes: concerns.

  - Directed edges: dependencies.

  - Placement: where each concern and its required context currently lives.

- Identify cycles, hidden dependencies, and accidental distance between related concerns.

- Derive an execution order by topologically sorting the graph.

  - Record cycles as unresolved ordering constraints; a cyclic graph has no complete topological order.

## Abduce

- Reshape the topology where evidence exposes accidental coupling or distance.

  - Split an entangled concern.

  - Merge concerns that cannot be independently understood or verified.

  - Move or collocate the parts required for one local decision.

  - Remove an accidental dependency or make an unavoidable one explicit.

- Preserve external contracts unless the topology model demonstrates they are wrong.

## Deduce

- State the expected effects on boundaries, dependencies, placement, and execution order.

## Test

- Verify every changed boundary and dependency.

- Verify that the resulting execution order remains valid.

## Induce

- Compare the proposed topology with the current one.

  - Count concepts, boundaries, dependencies, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Record retained dependencies and why they cannot be removed.

- Update the topology whenever later evidence contradicts a node, edge, boundary, or placement.
