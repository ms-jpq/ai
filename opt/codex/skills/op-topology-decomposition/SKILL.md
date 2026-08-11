---
name: op-topology-decomposition
description: Simplify flow across boundaries.
---

# Topology Decomposition

## Artifact

- The system concern.

- A covering hierarchy of concerns sufficient to achieve the system concern.

- A nested basis of named elements, each defined by a primary concern and explicit boundary.

- Containment and explicit flows between elements form the topology.

> apply to rest of this skill

## Observation

- Select the affected system.

  - State the system concern.

  - Record its external boundary and ordering constraints.

- Identify its current hierarchy of concerns and elements.

  - Associate each element with its current concerns.

  - Record each element's boundary, containment, placement, and required context.

- Map each flow's direction and dependency.

- Topologically sort the flow graph to derive an execution order.

  - Record each cycle as an unresolved ordering constraint.

## Abduction

_Devise an explanation for observations._

- Treat external boundaries as fixed unless evidence invalidates them.

- Identify the gap between the current concern hierarchy and the system concern, then hypothesize a covering hierarchy that closes it.

- Explore candidate topology changes, including:

  - Replace the topology with a distinct known pattern.

  - Merge elements that cannot be independently understood or verified.

  - Merge elements that share the same concerns.

  - Split an element that holds independent concerns.

  - Move an element beneath a boundary that contains its primary concern.

  - Enclose a system as an element within a larger topology.

  - Apply any other change that yields a simpler hierarchy of concerns, elements, containment, and flows.

### Heuristic

- Candidates for local reasoning are a strong signal of emergent concerns.

- Decomposition may temporarily increase complexity.

  - For deeply entangled subgraphs, temporarily aggregate elements that share any concern, even when it is not primary, until the aggregate exposes an emergent concern or a clearer partition.

## Deduction

_Derive consequences of the explanation._

- Derive observable consequences of the proposed topology:

  - Its concern hierarchy achieves the system concern.

  - Each changed element has one primary concern, a justified place in the hierarchy, and can be understood from its boundary and required flows.

  - Its flow graph yields the required execution order or exposes an unresolved ordering constraint.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived consequences against the affected system.

- Compare the proposed topology with the current one.

  - Count concerns, elements, containment relations, boundaries, flows, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Retain only necessary concerns, elements, containment relations, and flows; revise the topology when evidence contradicts the model.
