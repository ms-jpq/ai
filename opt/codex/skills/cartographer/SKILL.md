---
name: cartographer
description: Maintain a persistent atlas of work that brings the system toward its intended model and exposes the widest frontier of independently executable work.
---

# Cartographer

- The system model describes what should exist and how it should work.

- The current system is what actually exists and how it behaves.

- The atlas models the operations needed to move the current system toward the intended model, their dependencies, and their completion evidence.

  - Work units describe those operations for contributors to carry out.

  - A ticketing system is one representation of the atlas, using tickets, projects, milestones, and labels.

- Findings from the work can revise both the atlas and the system model.

---

## Artifact (Output)

_State the intended properties declaratively._

- A persistent atlas covering the target design, including integration and verification.

  - Missing work is added, stale or inaccurate work units are corrected, unclear descriptions are clarified, and extraneous work is pruned.

  - Dependencies justify necessary waits and state release conditions. Independent work remains separate, with integration work identified.

- The execution frontier includes all unstarted work units with satisfied prerequisites and start conditions, identifying which can proceed together without conflicts.

  - A contributor can determine what to do, what is out of scope, and how to check completion from the work unit and its references alone.

- Pending, active, and closed work retains its identities, ownership, history, and evidence across revisions.

  - Contributors may be humans or AI agents.

- Unresolved gaps and discrepancies remain explicit, including incomplete or stale claims.

---

## Observation (Input)

_State the input categories and their roles._

- Target design, desired outcomes, and constraints define what the work must achieve.

- The current implementation and evidence from execution and review establish what exists and which completion claims are supported.

- The existing atlas and its history supply work units, dependencies, ownership, and prior decisions to reconcile.

- Grouping and classification conventions determine how work is organized and found.

---

## Abduction

_Devise an explanation for observations._

- Explain omissions and conflicting or stale claims, then propose corrections.

- Specify each work unit's outcome, constraints, scope, prerequisites, source context, and completion evidence.

- Keep grouping, classification, and execution dependencies distinct.

- State what satisfies each dependency.

  - Starting work, reviewing results, and integrating them may require different conditions.

- Split, merge, or regroup proposed work to remove duplication and unnecessary coordination.

---

## Deduction

_Derive consequences of the explanation._

- Trace how proposed changes affect coverage, ownership, active work, dependent units, and readiness.

- Check whether the proposed outcomes combine into the intended result, including integration work.

- State what a fresh reader must recover from each unit and its references to carry out and verify the work.

- For progress views, define the scope, measurement unit, and treatment of completion, reopening, scope changes, and splits or merges.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Apply authorized revisions and check them against current evidence.

  - Coordinate changes with owners of active work and record whether their current attempt can continue, needs revision, or is superseded.

  - Verify completed work before relying on it as a prerequisite. Preserve its closure history when reopening it or adding follow-up work.

- Check coverage in both directions: required outcomes have work and acceptance checks, and work contributes to required outcomes.

- Give a fresh reader only the work unit and its references.

  - Compare their reconstructed assignment with the source requirements and repair missing context where it belongs.

- Recompute the frontier after changes. Check for blocking cycles and conflicts over ownership, interfaces, or shared resources.

- Derive progress views from recorded history.

  - Separate scope changes from completion.

  - Do not count both parents and children for the same outcome.

- Record unresolved discrepancies and revisit affected operations as findings change the atlas.

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
