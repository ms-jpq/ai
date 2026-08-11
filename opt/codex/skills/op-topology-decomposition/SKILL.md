---
name: op-topology-decomposition
description: Simplify flow across boundaries.
---

# Topology Decomposition

## Artifact

- The system concern.

- A covering set of concerns sufficient to achieve the system concern.

- A basis of named elements, each defined by a primary concern and explicit boundary.

- Explicit flows between elements form the topology.

## Observation

- Select the affected system.

  - State the system concern.

  - Record its external boundary and ordering constraints.

- Identify its current concerns and elements.

  - Associate each element with its current concerns.

  - Record each element's boundary, placement, and required context.

- Map each flow's direction and dependency.

- Topologically sort the flow graph to derive an execution order.

  - Record each cycle as an unresolved ordering constraint.

## Abduction

_Devise an explanation for observations._

- Treat external boundaries as fixed unless evidence invalidates them.

- Diagnose what prevents the current concern set from achieving the system concern.

- Hypothesize a covering set of concerns and a topology that achieves the system concern.

- Explore candidate topology changes, including:

  - Replace the topology with a distinct known pattern.

  - Merge elements that cannot be independently understood or verified.

  - Merge elements that share the same concerns.

  - Split an element that holds independent concerns.

  - Enclose a system as an element within a larger topology.

  - Apply any other change that yields a simpler basis of concerns, elements, and flows.

### Heuristic

- Candidates for local reasonability is a strong signal for emergent concerns.

- Decomposition may temporarily increase complexity.

  - For deeply entangled subgraphs, temporarily aggregate elements that share any concern, even when it is not primary, until the aggregate exposes an emergent concern or a clearer partition.

## Deduction

_Derive consequences of the explanation._

- Derive observable consequences of the proposed topology:

  - Its concerns achieve the system concern.

  - Each changed element has one primary concern and can be understood from its boundary and required flows.

  - Its flow graph yields the required execution order or exposes an unresolved ordering constraint.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test whether the proposed concern set achieves the system concern.

- Test changed boundaries, flows, and execution order.

- Compare the proposed topology with the current one.

  - Count concerns, elements, boundaries, flows, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Retain only necessary concerns, elements, and flows; revise the topology when evidence contradicts the model.
