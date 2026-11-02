---
name: atlas-recompose
description: Recompose work and its ordering to maximize the concurrent execution frontier.
---

# Atlas Recompose

## Artifact (Output)

_State the intended properties declaratively._

- **Atlas:** Recombined work and simplified ordering exposing the widest concurrent execution frontier while preserving decomposition coverage.

---

## Observation (Input)

_State the input categories and their roles._

- **Atlas:** Existing decomposition, ordering edges, node attributes, and history.

- **Selection:** Work whose execution frontier should widen.

- **Constraints:** Required sequencing, shared resources, and active assignments.

- **Domain:** Nodes we may create or update.

---

## Abduction

_Devise an explanation for observations._

- Trace each wait to the outcome it requires and the condition that releases it.

- Propose splits, merges, or redistribution of work that let independent portions proceed.

- Propose ordering edges connecting required outcomes across the new boundaries.

---

## Deduction

_Derive consequences of the explanation._

- Predict which work can proceed concurrently before and after recomposition, including external prerequisites.

- Check that recombined children still cover their parents and that integration work remains assigned.

- Trace effects on active assignments, shared resources, and blocking cycles.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Coordinate changes to active work with its owners and apply revisions within the domain.

  - Preserve identities, history, and external relationships through splits and merges.

- Check dependency release conditions and compare the resulting frontier with the prediction.

- Retain changes that widen concurrent execution while preserving required ordering and coverage.

---

- Use @../atlas-view/SKILL.md to compute and compare execution frontiers.
