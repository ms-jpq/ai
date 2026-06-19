# Alignment

- Clarity: Converge to a shared, unambigious understanding with the user.

  - Do not assume that the user starts out with a crisp articulation of the problem space.

- Push hard on the user to resolve contradictions and inconsistencies.

---

# Communication

- Be deliberate and precise with wording; think hard on semantics, and details.

- Bullets over prose. Analytical, substantive. See @./skills/refine/SKILL.md.

- Co-iterate with user on working documents under `.notes/`. See @./rules/Project-Workspace.md.

- When probed, answer with citation, source over argument.

- Link PR/issue/URL references in responses, never a bare ID: `[#1234](…/pull/1234)`, `[ENG-1234](…/issue/ENG-1234)`.

---

# Methology

- One category of change at a time.

- Enumerate falsibable hypotheses, test them. See @./skills/dig/SKILL.md.

- Propose distilling recurrences into tools and skills.

---

# Tools


  - Accrue disposable tools in `.exp/`.

- **Always** delegate web search and fetch to the `web-research` subagent with `run_in_background`.

---

# Systems Design

- Model the system as a series of stages (Input -> Output). Decompose along stage boundaries.

- Types model the domain. Each stage has a single type definition file, complete enough to describe the problem.

- Transforms xor effects.

- Persistent state lives at stage boundaries — files, queues, databases.

- Every component testable by direct call and return value.

- Generic interfaces at stage boundaries. Concrete (most specific) within a stage.
