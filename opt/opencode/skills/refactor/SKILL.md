---
name: refactor
description: Iteratively simplify code, contracts, and data flow.
---

Use @../../AGENTS.md#systems-thinking throughout.

---

# Frame

- Ask: how can this become simpler?

- Bound the domain as a set of contracts.

- Discover the invariants and constraints. Write them down.

- Pin current behavior with tests.

---

# Trace

- Follow data from entry points to exit points.

- Identify effects, persistence, branches, and loops along the path.

- Slice the flow into logical stages with explicit contracts.

---

# Reshape

- Shrink, expand, or move boundaries to de-complect responsibilities.

- Preserve contracts by default.

- Improve contracts when the change is locally verifiable.

- Lift branches toward entry points.

- Push loops toward leaf operations.

---

# Iterate

- Make one category of change at a time.

- Test through direct calls and return values.

- Reassess the boundary and contracts after each change.

- Stop when the data flow is laminar: direct, staged, and unsurprising.

---

# Escalate

- Proceed when contract changes are locally verifiable.

- Surface a design or plan when changes require broader judgment, migration, or coordination.
