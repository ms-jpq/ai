---
name: op-topology-recomposition
description: Iteratively resolve structural problems in a concern hierarchy.
---

# Topology Recomposition

- Use @../op-purpose-formation/SKILL.md when external boundaries need revision.

- Use @../op-mechanism-alignment/SKILL.md when a structural proposal changes how effects are produced, not merely where responsibilities reside or how parts connect.

- When invoked independently, establish the concerns and constraints the topology must accommodate.

---

## Artifact (Output)

_State the intended properties declaratively._

- A decomposition of the desired outcome into intermediate outcomes, their dependencies, and explicit conditions for achieving or maintaining each outcome.

  - Their combined achievement satisfies the desired outcome and each dependent outcome's prerequisites.

- A named hierarchy of parts that achieves those outcomes and resolves structural problems in the concern hierarchy.

  - Boundaries, containment relations, and flows are explicit.

  - The organization makes representative changes easier to understand, carry out, and verify while preserving required outcomes.

- An explicit mapping from framed concerns to outcomes and from outcomes to parts.

  - Each part's boundary and placement are justified.

  - Concerns needing no structural embodiment are identified and explained.

- Cycles that prevent required ordering are resolved. Retained cycles have explicit sources and iteration or feedback semantics.

---

## Observation (Input)

_State the input categories and their roles._

- Framed concerns, system purpose, desired outcome, and external boundary define the topology's obligations and scope.

- Current parts, boundaries, containment, flows, and ordering constraints provide the structure to revise.

  - Evidence of achieved outcomes and addressed concerns supports assessment of existing coverage.

- Representative changes and cross-part interactions provide evidence of structural coupling.

- Known cycles, their sources, and observed behaviour support distinguishing ordering obstructions from iteration or feedback.

---

## Abduction

_Devise an explanation for observations._

- Treat external boundaries as fixed for the pass.

- Decompose the desired outcome into intermediate outcomes that together suffice to achieve it.

  - Specify what must hold at each intermediate outcome before prescribing how to achieve it.

  - Distinguish necessary dependencies from incidental sequencing.

- Organize parts around those outcomes by exploring topology changes, including:

  - Replace the topology with a distinct known pattern.

  - Move a part upward, downward, or laterally in the hierarchy to give its primary concern the right scope.

  - Merge parts when a shared boundary reduces the context needed to understand or verify their responsibilities.

  - Split a part when separate boundaries allow its responsibilities to be understood and verified independently.

  - Enclose a system as a part within a larger topology.

  - Resolve a cycle when it prevents a required order by changing the parts or flows that create it.

    - Retain other cycles only as explicit iterations or feedback loops.

### Heuristic

- Recomposition may temporarily increase complexity.

  - For deeply entangled subgraphs, temporarily aggregate parts sharing any concern across hierarchy levels, including non-primary concerns, until the aggregate exposes an emergent concern or clearer partition.

- Prefer a single event loop for events requiring shared ordering, unless independent ownership or progress requires separate loops.

- Push branches toward callers that own the decision and loops toward operations that own the collection, when this reduces cross-boundary dependencies.

---

## Deduction

_Derive consequences of the explanation._

- Derive whether achieving the intermediate outcomes satisfies the desired outcome and each dependent outcome's prerequisites.

- Trace a representative change through the proposed parts to predict which boundaries and flows it must cross.

- Derive an execution order from precedence dependencies and identify remaining conflicts.

- Derive how each retained cycle advances, terminates, or regulates its state under the proposed structure.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived consequences by comparing the proposed topology with the current one.

  - Check the intermediate outcomes and their combined sufficiency against representative cases and counterexamples.

  - Trace the same representative change through both topologies, comparing required context, coordinated changes, and verification effort.

  - Prefer the topology that makes the change easier to understand, carry out, and verify while preserving required outcomes.

  - Fewer parts or flows alone do not establish an improvement.

- Retain only necessary mappings, parts, containment relations, and flows, revising the topology when evidence contradicts the model.
