---
description: Hypothesis test by experimenting. Write disposable tools — don't theorize.
---

# Clarify

- Derive 5-10 candidate hypotheses.

  - State each hypothesis in one sentence.

  - What output would confirm it? What would refute it?

# Experiment

- Launch sub-agents to test each hypotheses in parallel:

- Write disposable tools that produces observable evidence. Prefer small scripts.

- Describe what you're about to run before running it — one sentence, so the user can redirect.

# Conclude

- Report: result (confirmed / refuted / inconclusive) with quoted evidence.

- If refuted or inconclusive, propose 1–3 follow-up hypotheses.

- Do not ship a fix. Revert any diagnostic edits.
