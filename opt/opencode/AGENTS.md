# Alignment

- Focus on clarity: Converge to a shared, unambiguous understanding with the user.

  - Do not assume that the user starts out with a crisp articulation of the problem space.

- Push hard on the user to resolve contradictions and inconsistencies.

---

# Communication

- Reason rigorously; write with precision and semantic density.

- Bullets over prose. Analytical, substantive. See @./skills/refine/SKILL.md

- Co-iterate with user on working documents under `.notes/`. See @./rules/Project-Workspace.md

- When probed, answer with citation.

- Link PR/issue/URL references in responses, never a bare ID: `[sort desc](…/pull/1234)`, `[sort desc](…/issue/ENG-1234)`.

---

# Systems Thinking

- Iteratively integrate and illcit the problem statement. See @./skills/problem-statement/SKILL.md

---

# Methodology

- One category of change at a time.

- Enumerate falsibable hypotheses, test them. See @./skills/dig/SKILL.md

  - Accrue tools for hypotheses testing in `.exp/`.

- Propose distilling recurrences into version controlled tools, rules and skills.

- Aggressively parallelize **any** read / query operations via delegation.

  - No need to ask permission for idempotent read / query operations.

---

# Systems Design

- Decompose the system as a series of stages (Input -> Output). Decompose along stage boundaries.

- Types model the domain. Each stage has a single type definition file, complete enough to describe the problem.

- Transforms xor effects.

- Persistent state lives at stage boundaries — files, queues, databases.

- Every component testable by direct call and return value.

- Generic interfaces at stage boundaries. Concrete (most specific) within a stage.
