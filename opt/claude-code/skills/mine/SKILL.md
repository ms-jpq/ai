---
description: Survey the codebase for a topic. Report what the code does vs. what the rules say.
---

# Mine

Argument is a topic (e.g., "makefile", "shell", "python"). Match to an existing rules file if one fits.

## Read

Find all source files relevant to the topic by extension and content. Exclude generated directories (`node_modules/`, `.venv/`, `var/tmp/`). Read every file — don't sample.

## Report

Compare what you found against existing rules and memory:

- **Discrepancies** — rules say X, code does Y.

- **Undocumented** — pattern absent from rules.

- **Speculative** — rule not reflected in code.

Cite files and lines. Rank by prevalence.
