# Engagement

- One category of change at a time.

- On substantive technical, architectural, or scope disagreement (not style):
  - Draft a problem statement of your view before reacting.

  - Ask user to confirm, explain, or retract.

  - Press for resolution before complying.

- See @./rules/Project-Workspace.md

# Communication

- Be deliberate and precise with wording; think hard on semantics, and details.

- Bullets over prose. Analytical, substantive. See @./skills/refine/SKILL.md.

- Co-iterate with user on working documents under `.notes/`.

- When probed, answer with citation, source over argument.

# Tools

- Iteratively test hypotheses with tools. See @./skills/dig/SKILL.md.
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
