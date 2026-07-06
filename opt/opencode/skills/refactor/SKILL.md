---
name: refactor
description: Iteratively simplify code, contracts, and data flow.
---

Use @../../AGENTS.md#systems-thinking throughout.

---

# Refactor

- Ask: how can this code become simpler?

- Bound the domain as a set of contracts.

- Follow data from entry points to exit points.

- Move or resize boundaries to de-complect responsibilities.

- Preserve contracts by default.

- Improve contracts when the change is locally verifiable.

- Divide the flow into stages with explicit contracts.

- Lift branches toward entry points.

- Push loops toward leaf operations.

- Iterate until the data flow is laminar: direct, staged, and unsurprising.

- Surface a design or plan when changes require broader judgment, migration, or coordination.
