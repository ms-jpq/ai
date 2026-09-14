---
name: op-topology-recomposition
description: Iteratively resolve structural problems in a concern hierarchy.
---

# Topology Recomposition

## Artifact (Output)

- A named hierarchy of parts that resolves structural problems in the concern hierarchy.

  - Explicit boundaries, containment relations, and flows.

- An explicit mapping from framed concerns to parts.

  - A justified boundary and placement for each part, with reasons for concerns needing no structural embodiment.

- Explicit cycles, their sources, and their precedence, iteration, or feedback semantics.

## Observation (Input)

- Take the framed concerns, system purpose, and external boundary as inputs.

- When invoked independently, state the concerns and constraints the topology must accommodate.

- Record the affected system's parts, boundaries, containment, flows, and ordering constraints.

- Map framed concerns to their current parts.

- Record each cycle, its source, and whether it prevents a required order or represents iteration or feedback.

## Abduction

_Devise an explanation for observations._

- Treat external boundaries as fixed unless evidence invalidates them.

- Identify which boundaries or flows force a concern to be understood across several parts.

- Explore candidate topology changes, including:

  - Replace the topology with a distinct known pattern.

  - Move a part upward, downward, or laterally in the hierarchy to give its primary concern the right scope.

  - Merge parts that share concerns or cannot be independently understood or verified.

  - Split a part that holds independent concerns.

  - Enclose a system as a part within a larger topology.

  - Resolve a cycle when it prevents a required order by changing the parts or flows that create it.

    - Retain other cycles only as explicit iterations or feedback loops.

### Heuristic

- Recomposition may temporarily increase complexity.

  - For deeply entangled subgraphs, temporarily aggregate parts that share any concern across hierarchy levels, even when it is not primary, until the aggregate exposes an emergent concern or a clearer partition.

- Build a singular central event loop for event-driven systems.

- Push branches up and loops down.

## Deduction

_Derive consequences of the explanation._

- Trace a representative change through the proposed parts to predict which boundaries and flows it must cross.

- Derive an execution order from precedence dependencies and identify remaining conflicts.

- Derive how each retained cycle advances, terminates, or regulates its state under the proposed structure.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived consequences by comparing the proposed topology with the current one.

  - Count mappings, parts, containment relations, boundaries, flows, exceptions, and remote reads.

  - Prefer the shape that makes the next change locally understandable and verifiable.

- Retain only necessary mappings, parts, containment relations, and flows.

- Revise the topology when evidence contradicts the model.
