---
name: op-topology-recomposition
description: Iteratively reshape concern boundaries.
---

# Topology Recomposition

## Artifact

- A named element hierarchy with explicit boundaries and flows.

- An explicit mapping from framed concerns to elements.

  - Note each cycle, its source, and whether it is a precedence constraint, iteration, or feedback loop.

## Observation

- Record the affected system's elements, boundaries, containment, flows, and ordering constraints.

- Map framed concerns to their current elements.

- Record each cycle that prevents a required order as a candidate topology change.

## Abduction

_Devise an explanation for observations._

- Treat external boundaries as fixed unless evidence invalidates them.

- Diagnose how the current element mapping fails to embody the framed concern hierarchy locally.

- Explore candidate topology changes, including:

  - Replace the topology with a distinct known pattern.

  - Move an element upward, downward, or laterally in the hierarchy to give its primary concern the right scope.

  - Merge elements that share concerns or cannot be independently understood or verified.

  - Split an element that holds independent concerns.

  - Enclose a system as an element within a larger topology.

  - Resolve a cycle when it prevents a required order by changing the elements or flows that create it.

    - Retain other cycles only as explicit iterations or feedback loops.

  - Apply any other change that simplifies elements, containment, or flows without losing framed concerns.

### Heuristic

- Push branches up and loops down.

- Recomposition may temporarily increase complexity.

  - For deeply entangled subgraphs, temporarily aggregate elements that share any concern across hierarchy levels, even when it is not primary, until the aggregate exposes an emergent concern or a clearer partition.

## Deduction

_Derive consequences of the explanation._

- Derive observable consequences of the proposed topology:

  - Each framed concern has an explicit structural embodiment or a reason it needs none.

  - Each changed element has a justified boundary and place in the containment hierarchy.

  - Its acyclic flow graph yields the required execution order; each retained cycle is an explicit iteration or feedback element.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived consequences by comparing the proposed topology with the current one.

  - Count mappings, elements, containment relations, boundaries, flows, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Retain only necessary mappings, elements, containment relations, and flows; revise the topology when evidence contradicts the model.
