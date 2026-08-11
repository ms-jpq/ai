---
name: op-topology-decomposition
description: Simplify flow across boundaries.
---

# Topology Decomposition

## Artifact

- A basis of named elements, each defined by an explicit boundary.

- Explicit flows between elements form the topology.

## Observation

- Select the system and topology affected by the decision.

  - Record its external boundary and ordering constraints.

- Identify candidate elements in the affected system.

  - Record each candidate’s current boundary, placement, and required context.

- Map each flow’s direction and dependency.

- Identify hidden flows, cycles, and accidental distance.

- Topologically sort the flow graph to derive an execution order.

  - Record each cycle as an unresolved ordering constraint.

## Abduction

_Devise an explanation for observations._

- Hypothesize how current boundaries and flows produce the observed coupling, distance, or ordering failure.

- Propose a revised topology:

  - Split an entangled element.

  - Merge elements that cannot be independently understood or verified.

  - Move or collocate what one local decision requires.

  - Remove an accidental flow or make a necessary one explicit.

  - Reorder work from the flow graph.

  - Integrate systems by merging their topologies and exposing shared flows.

- Treat external boundaries as fixed unless evidence invalidates them.

## Deduction

_Derive consequences of the explanation._

- Predict changes to boundaries, flows, placement, and execution order.

- Predict that each changed element can be understood from its boundary and required flows.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the predicted boundaries, flows, and execution order.

- Compare the proposed topology with the current one.

  - Count elements, boundaries, flows, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Retain only necessary flows; revise the topology when evidence contradicts an element, flow, boundary, or placement.
