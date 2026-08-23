---
name: op-topology-decomposition
description: Iteratively reshape concern boundaries.
---

# Topology Decomposition

## Artifact

- The system concern and a covering concern set sufficient to achieve it.

- A nested basis of named elements, each defined by a primary concern and explicit boundary.

- An explicit many-to-many mapping between concerns and elements.

- Containment and explicit flows between elements form the topology.

  - Note each cycle, its source, and whether it is a precedence constraint, iteration, or feedback loop.

## Observation

- Select the affected system; state its concern, external boundary, and ordering constraints.

- Identify its current concerns, elements, and containment hierarchy.

  - Map concerns to their current elements.

  - Record each element's boundary, containment, placement, and required context.

- Map each flow's direction and dependency.

- Enclose each retained iterative process or feedback loop as an explicit element, then derive execution order from the resulting flow graph.

  - Record each cycle that prevents a required order as a candidate topology change.

## Abduction

_Devise an explanation for observations._

- Treat external boundaries as fixed unless evidence invalidates them.

- Identify the gap between the current concern set and the system concern, then hypothesize a covering set that closes it.

- Explore candidate topology changes, including:

  - Replace the topology with a distinct known pattern.

  - Move an element upward, downward, or laterally in the hierarchy to give its primary concern the right scope.

  - Merge elements that share concerns or cannot be independently understood or verified.

  - Split an element that holds independent concerns.

  - Enclose a system as an element within a larger topology.

  - Resolve a cycle when it prevents a required order by changing the elements or flows that create it.

    - Retain other cycles only as explicit iterations or feedback loops.

  - Apply any other change that yields a simpler basis of concerns, elements, containment, and flows.

### Heuristic

- Candidates for local reasoning are a strong signal of emergent concerns.

- Push branches up and loops down.

- Decomposition may temporarily increase complexity.

  - For deeply entangled subgraphs, temporarily aggregate elements that share any concern across hierarchy levels, even when it is not primary, until the aggregate exposes an emergent concern or a clearer partition.

## Deduction

_Derive consequences of the explanation._

- Derive observable consequences of the proposed topology:

  - Its concern set achieves the system concern.

  - Each changed element has one primary concern, a justified place in the containment hierarchy, and explicit cross-cutting concerns.

  - Its acyclic flow graph yields the required execution order; each retained cycle is an explicit iteration or feedback element.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived consequences by comparing the proposed topology with the current one.

  - Count concerns, concern-to-element mappings, elements, containment relations, boundaries, flows, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Retain only necessary concerns, mappings, elements, containment relations, and flows; revise the topology when evidence contradicts the model.
