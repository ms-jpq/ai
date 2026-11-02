---
name: cartographer
description: Revise a persistent graph of work and dependencies to cover the changes from the current system to the intended system.
---

# Cartographer

- Work graph:

  - Nodes:

    - Attributes include completion state and work category.

  - Edges:

    - **Decomposition edges** describe what work belongs within other work.

    - **Ordering edges** describe what work must precede other work.

      - The concurrent **execution frontier** contains selected nodes with satisfied ordering constraints.

    - A decomposition edge does not by itself imply an ordering edge.

  - Domain:

    - The subset of nodes we may create or update.

    - Relationships may extend beyond this subset.

- `work graph + information → revised work graph`.

  1. Maintain the intended system model independently of the work graph.

  2. Reconcile work-graph nodes with the model and existing work, updating their attributes.

     - Project the intended system model into the work graph.

  3. Maximize the concurrent execution frontier by removing unnecessary sequencing and revising work boundaries.

  4. Derive views and clusters from node attributes and relationships.

---

## Artifact (Output)

_State the intended properties declaratively._

- Nodes:

  - Together they account for the work needed to reach the intended system, including integration and verification. Missing work is added and extraneous work is pruned.

  - Each node and its references specify the intended outcome, scope, and acceptance checks without requiring the originating conversation. Stale or inaccurate attributes are corrected and unclear descriptions are clarified.

  - Completion state and work category are explicit. Identity, ownership, history, and evidence are preserved across revisions.

- Decomposition edges:

  - Children account for their parent's outcome, including the work needed to integrate and verify their results.

- Ordering edges:

  - Each edge expresses a necessary prerequisite and an explicit release condition.

  - Unnecessary sequencing is removed so independent work can proceed concurrently.

- Unresolved gaps and discrepancies remain explicit.

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

- Surface design questions when findings challenge the intended system.

---

## Deduction

_Derive consequences of the explanation._

- Trace the proposed revisions through active work, ownership, dependants, and the execution frontier.

- Derive whether the combined work outcomes would produce the intended system.

- State what a fresh reader must recover from each unit and its references to carry out and verify the work.

- For progress assessment, define the scope, measurement unit, and effects of completion, reopening, scope changes, and splits or merges.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Coordinate revisions with owners of active work and record the effect on their attempt.

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

## Graph Representation

- In a ticketing system:

  - Tickets represent nodes.

  - Dependencies represent ordering edges.

  - Projects and milestones cluster nodes by scope or delivery target.

  - Labels classify nodes within or across clusters.

  - Parent–child relationships represent decomposition edges.

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
