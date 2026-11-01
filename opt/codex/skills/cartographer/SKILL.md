---
name: cartographer
description: Maintain a persistent atlas of work that brings the system toward its intended model and exposes the widest frontier of independently executable work.
---

# Cartographer

- The system model describes what should exist and how it should work.

- The current system is what actually exists and how it behaves.

- The atlas models the operations needed to move the current system toward the intended model, their dependencies, and their completion evidence.

  - Work items describe those operations for contributors to carry out.

  - A ticketing system is one representation of the atlas, using tickets, projects, milestones, and labels.

- Findings from the work can revise both the atlas and the system model.

---

## Artifact (Output)

_State the intended properties declaratively._

- A persistent atlas covering the required changes and their execution order.

  - Every required outcome is linked to completed work with evidence, remaining work with acceptance checks, or an explicit unresolved gap.

  - Combined work outcomes account for the target design, including integration and verification.

  - Each work item contributes to a required outcome.

  - Every dependency has a reason and an explicit release condition.

  - Sequencing reflects necessary prerequisites. Independently executable work remains separate, with integration obligations explicit.

- The execution frontier includes all unstarted items whose prerequisites and start conditions are satisfied, with concurrently executable sets identified.

  - Each item supplies enough context, scope, and completion checks for a contributor to act without reconstructing the originating conversation.

  - Conflicts over ownership, interfaces, or shared resources are explicit.

- Pending, active, and closed work retains its identities, ownership, history, and evidence across revisions.

  - Contributors may be humans or AI agents.

- Unresolved gaps and discrepancies remain explicit, including incomplete or stale claims.

---

## Observation (Input)

- Read the desired outcomes, design, constraints, implementation, and existing atlas, including execution and review evidence.

- Inspect relevant history, ownership, groupings, and classification conventions.

- Select the relevant operations below.

---

## Abduction

_Devise an explanation for observations._

- Explain omissions and conflicting or stale claims, then propose corrections.

- Specify each work item's outcome, constraints, scope, prerequisites, source context, and completion evidence.

- Keep grouping, classification, and execution dependencies distinct.

- State what satisfies each dependency.

  - Starting work, reviewing results, and integrating them may require different conditions.

- Split, merge, or regroup proposed work to remove duplication and unnecessary coordination.

---

## Deduction

_Derive consequences of the explanation._

- Trace how proposed changes affect coverage, ownership, active work, dependent items, and readiness.

- Check whether the proposed outcomes combine into the intended result, including integration work.

- State what a fresh reader must recover from each item and its references to carry out and verify the work.

- For progress views, define the scope, measurement unit, and treatment of completion, reopening, scope changes, and splits or merges.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply authorised revisions and check them against current evidence.

  - Coordinate changes with owners of active work and record whether their current attempt can continue, needs revision, or is superseded.

  - Verify completed work before relying on it as a prerequisite. Preserve its closure history when reopening it or adding follow-up work.

- Check coverage in both directions: required outcomes have work and acceptance checks, and work contributes to required outcomes.

- Give a fresh reader only the work item and its references.

  - Compare their reconstructed assignment with the source requirements and repair missing context where it belongs.

- Recompute the frontier after changes. Check for blocking cycles and conflicts over ownership, interfaces, or shared resources.

- Derive progress views from recorded history.

  - Separate scope changes from completion.

  - Do not count both parents and children for the same outcome.

- Record unresolved discrepancies and revisit affected operations as findings change the atlas.

---

## Operations

| Operation           | Question                                    | Result                                                  |
| ------------------- | ------------------------------------------- | ------------------------------------------------------- |
| Coverage discovery  | What is missing?                            | Missing work and relationships                          |
| Reconciliation      | What is inaccurate or stale?                | Corrected claims and unresolved discrepancies           |
| Work specification  | How should the work be described?           | Actionable work items and acceptance checks             |
| Work organisation   | How should work connect and be grouped?     | Revised boundaries, relationships, and readiness        |
| Context recovery    | Can a reader recover enough context to act? | Recovered context and identified gaps                   |
| Progress assessment | What remains, and how is work progressing?  | Progress views separating completion from scope changes |
