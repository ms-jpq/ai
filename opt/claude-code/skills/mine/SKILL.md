---
description: Survey the workspace for a topic. Report patterns in the corpus.
---

# Discover

- Find all source files relevant to the topic:
  - By filetype.

  - By embedded content.

  - Read every file — don't sample.

- What does the corpus consistently do?
  - Each finding is a specific, falsifiable claim about content.

  - Cite files and lines. Rank by prevalence.

# Compare

- Load the matching rules file and memory as the baseline.

- **Discrepancies** — rules say X, corpus does Y.

- **Undocumented** — pattern present in corpus, absent from rules.

- **Speculative** — rule not reflected in the corpus.

- Omit this section when no rules file exists.

# Output

- Write `<topic>.md` in the current working directory.
