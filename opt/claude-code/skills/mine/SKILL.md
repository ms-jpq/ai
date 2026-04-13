---
description: Survey the workspace for a topic. Report patterns in the corpus.
---

# Discovery

- Find all source files relevant to the topic:
  - By extension — files written in the topic's language.
  - By content — files that embed or invoke it without being written in it.
  - Exclude generated directories (`node_modules/`, `.venv/`, `var/tmp/`).
  - Read every file — don't sample.

- What recurring choices does the corpus make? Each finding is a specific, falsifiable claim — cite files and lines. Rank by prevalence.

# Comparison

- Load the matching rules file and memory as the baseline.

- **Discrepancies** — rules say X, corpus does Y.

- **Undocumented** — pattern present in corpus, absent from rules.

- **Speculative** — rule not reflected in any corpus.

# Output

- Write `<topic>.md` in this skill's directory.

- Discovery stands alone — Comparison is omitted when no rules file exists.
