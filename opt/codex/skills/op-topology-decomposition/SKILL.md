---
name: op-topology-decomposition
description: Simplify flow across boundaries.
---

# Topology Decomposition

## Artifact

- The system concern.

  - A covering set of concerns sufficient to achieve the system concern.

- A nested basis of named elements, each defined by a primary concern and explicit boundary.

- An explicit many-to-many mapping between concerns and elements.

- Containment and explicit flows between elements form the topology.

  - Note explicit cycles and their sources.

## Observation

- Select the affected system.

  - State the system concern.

  - Record its external boundary and ordering constraints.

- Identify its current concerns, elements, and containment hierarchy.

  - Associate each element with its current concerns.

  - Record each element's boundary, containment, placement, and required context.

- Map each flow's direction and dependency.

- Enclose each retained cycle as an explicit iterative element, then derive execution order from the resulting flow graph.

  - Record each unresolved cycle as a candidate topology change.

## Abduction

_Devise an explanation for observations._

- Treat external boundaries as fixed unless evidence invalidates them.

- Identify the gap between the current concern set and the system concern, then hypothesize a covering set that closes it.

- Explore candidate topology changes, including:

  - Replace the topology with a distinct known pattern.

  - Move an element upward, downward, or laterally in the hierarchy to give its primary concern the right scope.

  - Merge elements that cannot be independently understood or verified.

  - Merge elements that share the same concerns.

  - Split an element that holds independent concerns.

  - Enclose a system as an element within a larger topology.

  - Resolve an ordering constraint by changing the elements or flows that create it

    - Retain a cycle only in explicitly iterative systems.

  - Apply any other change that yields a simpler basis of concerns, elements, containment, and flows.

### Heuristic

- Candidates for local reasoning are a strong signal of emergent concerns.

- Decomposition may temporarily increase complexity.

  - For deeply entangled subgraphs, temporarily aggregate elements that share any concern across hierarchy levels, even when it is not primary, until the aggregate exposes an emergent concern or a clearer partition.

## Deduction

_Derive consequences of the explanation._

- Derive observable consequences of the proposed topology:

  - Its concern set achieves the system concern.

  - Each changed element has one primary concern, a justified place in the containment hierarchy, and explicit cross-cutting concerns.

  - Its acyclic flow graph yields the required execution order; each retained cycle is an explicit iterative element.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived consequences against the affected system.

- Compare the proposed topology with the current one.

  - Count concerns, concern-to-element mappings, elements, containment relations, boundaries, flows, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Retain only necessary concerns, mappings, elements, containment relations, and flows; revise the topology when evidence contradicts the model.
