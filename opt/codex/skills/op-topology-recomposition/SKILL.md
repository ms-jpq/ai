---
name: op-topology-recomposition
description: Iteratively resolve structural problems in a concern hierarchy.
---

# Topology Recomposition

## Artifact (Output)

_State the intended properties declaratively._

- **Components:** Units of the system with defined responsibilities.

- **Topology:** The components' boundaries, containment, and connections.

- **Concern mapping:** Which components address which concerns.

---

## Observation (Input)

_State the input categories and their roles._

- **Purpose and boundary:** What the system should achieve and what it includes.

- **Concerns:** What the structure must accommodate.

- **Topology:** Existing components, responsibilities, and relationships to revise.

- **Cases:** Behaviour and representative changes that reveal coverage, coupling, and ordering constraints.

---

## Abduction

_Devise an explanation for observations._

- Treat external boundaries as fixed for the pass.

- Decompose the system into components whose responsibilities together serve its purpose.

  - Define each component's responsibilities before choosing its implementation.

  - Distinguish necessary dependencies from incidental sequencing.

- Organize components around their concerns and responsibilities by exploring topology changes:

  - Replace the topology with a distinct known pattern.

  - Move a component within the hierarchy to give its primary concern the right scope.

  - Merge components when a shared boundary reduces the context needed to understand or verify their responsibilities.

  - Split a component when separate boundaries allow its responsibilities to be understood and verified independently.

  - Enclose a system as a component within a larger topology.

  - Resolve a cycle when it prevents a required order by changing the components or connections that create it.

### Heuristic

- For entangled subgraphs, temporarily group components that share concerns across hierarchy levels to reveal an emergent concern or clearer partition.

- Prefer a shared event loop for shared ordering and separate loops for independent ownership or progress.

- Push branches toward callers that own the decision and loops toward operations that own the collection, when this reduces cross-boundary dependencies.

---

## Deduction

_Derive consequences of the explanation._

- Derive whether the components' combined responsibilities cover the concerns and serve the system's purpose.

- Trace a representative change through the proposed components to predict which boundaries and connections it must cross.

- Derive an execution order from precedence dependencies and identify remaining conflicts.

- Derive how each retained cycle advances, terminates, or regulates its state under the proposed structure.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived consequences by comparing the proposed topology with the current one.

  - Check component responsibilities and their combined coverage against representative cases and counterexamples.

  - Trace the same representative change through both topologies, comparing required context, coordinated changes, and verification effort.

  - Prefer the topology that makes the change easier to understand, carry out, and verify while preserving required behaviour.

- Remove unnecessary components, concern mappings, containment relations, and connections.
