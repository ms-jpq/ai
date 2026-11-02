---
name: cartographer
description: Revise a persistent graph of work and dependencies to cover the changes from the current system to the intended system.
---

# Cartographer

- Work graph:

  - Nodes:

    - Attributes include completion state and work category.

  - Edges:

    - Structural edges describe relationships in the system model.

    - Ordering edges describe dependencies between units of work.

    - A structural edge does not by itself imply an ordering edge.

  - Domain:

    - The subset of nodes we may create or update.

    - Relationships may extend beyond this subset.

    - External ordering dependencies still constrain the execution frontier.

- `work graph + information → revised work graph`.

  1. Maintain the intended system model independently of the work graph.

  2. Project the model into work-graph nodes, reconciling them with existing work.

  3. Maximize the execution frontier by removing unnecessary sequencing and revising work boundaries.

  4. Assign labels to nodes for state, delivery target, and other relevant properties.

     - Mark completed nodes as done based on completion evidence, and recompute the execution frontier when state changes.

     - Derive views and clusters from labels as needed.

---

## Artifact (Output)

_State the intended properties declaratively._

- The revised work graph accounts for the work needed to reach the intended system, including integration and verification.

  - Missing work is added, stale or inaccurate work units are corrected, unclear descriptions are clarified, and extraneous work is pruned.

- Dependencies express necessary ordering and explicit release conditions, leaving independent work able to proceed separately.

- Each work unit and its references explain what to do, what is out of scope, and how to check completion without the originating conversation.

- Pending, active, and closed work retains its identities, ownership, history, and evidence across revisions.

- Unresolved gaps and discrepancies remain explicit, including incomplete or stale claims.

---

## Observation (Input)

_State the input categories and their roles._

- The existing work graph and its history are the state to revise.

- The intended system's model, desired outcomes, and constraints define the destination.

- The current system and evidence from execution and review establish the starting state and support or contradict recorded completion.

- New findings and decisions change what work is needed or how it relates.

- Grouping and classification conventions govern how work is organized and found.

---

## Abduction

_Devise an explanation for observations._

- Compare the current and intended systems with the work graph. Propose additions, corrections, clarifications, and removals where they disagree.

- Describe affected work units by outcome, scope, constraints, prerequisites, source context, and acceptance checks.

- Propose dependencies with explicit release conditions, distinguishing starting work, reviewing results, and integrating them.

- Split, merge, or regroup work to remove duplication and unnecessary sequencing.

  - Keep containment, classification, and execution dependencies distinct.

- When findings challenge the intended system, make the design question explicit rather than silently changing the destination.

---

## Deduction

_Derive consequences of the explanation._

- Trace the proposed revisions through active work, ownership, dependants, and the execution frontier.

- Derive whether completing the revised work would produce the intended system, including the joins between independently produced results.

- State what a fresh reader must recover from each unit and its references to carry out and verify the work.

- For progress assessment, define the scope, measurement unit, and effects of completion, reopening, scope changes, and splits or merges.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Coordinate revisions with owners of active work, recording whether their attempt can continue, needs revision, or is superseded.

- Verify completed work before relying on it as a prerequisite. Preserve its closure history when reopening it or adding follow-up work.

- Apply authorized revisions and compare the resulting work graph with the current and intended systems.

- Check coverage in both directions: required outcomes have work and acceptance checks, and work contributes to required outcomes.

- Give a fresh reader only the work unit and its references.

  - Compare their reconstructed assignment with the source requirements and repair missing context where it belongs.

- Check for blocking cycles and recompute the execution frontier.

- Derive progress views from recorded history.

  - Separate scope changes from completion.

  - Do not count both parents and children for the same outcome.

- Retain unresolved discrepancies and revisit affected operations when evidence or the intended system changes.

---

## Execution Frontier

- The execution frontier is the set of selected nodes whose constraints on ordering edges are satisfied. Structural edges do not determine readiness.

- Identify which selected work units can proceed together without conflicts over ownership, interfaces, or shared resources.

---

## Graph Representation

- In a ticketing system:

  - Tickets represent nodes.

  - Dependencies represent ordering edges, with conditions that release blocked work.

  - Projects and milestones cluster nodes by scope or delivery target.

  - Labels classify nodes within or across clusters.

  - Typed relationships represent structural edges. Cluster membership alone does not impose execution order.

---

## Operations

- Select the operations needed for the current pass.

| Operation           | Question                                    | Result                                                  |
| ------------------- | ------------------------------------------- | ------------------------------------------------------- |
| Coverage discovery  | What is missing?                            | Missing work and relationships                          |
| Reconciliation      | What is inaccurate or stale?                | Corrected claims and unresolved discrepancies           |
| Work specification  | How should the work be described?           | Actionable work units and acceptance checks             |
| Work organization   | How should work connect and be grouped?     | Revised boundaries, relationships, and readiness        |
| Context recovery    | Can a reader recover enough context to act? | Recovered context and identified gaps                   |
| Progress assessment | What remains, and how is work progressing?  | Progress views separating completion from scope changes |
