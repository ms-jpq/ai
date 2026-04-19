---
description: Hypothesis test by instrumenting and observing. Write disposable tools — don't theorize.
---

# Clarify

- State the hypothesis in one sentence.

- What output would confirm it? What would refute it?

- If the direction is vague, propose 2–3 candidate hypotheses. Ask which to dig first.

# Instrument

- Write a disposable tool that produces observable evidence. `tmp/claude/<name>.{sh,jq,ts,py}`.

- Prefer grep, jq, awk, small scripts over speculation.

- Describe what you're about to run before running it — one sentence, so the user can redirect.

- Does the tool's output cleanly distinguish confirm from refute?

# Observe

- Run it. Quote the output verbatim.

- If the answer is unclear or surprising, instrument more before concluding.

# Conclude

- Result: confirmed / refuted / inconclusive.

- Evidence: quoted output.

- If refuted or inconclusive, propose 1–3 follow-up hypotheses. Ask which to dig next.

- Don't ship a fix. If you added diagnostic edits to application code, revert them.
