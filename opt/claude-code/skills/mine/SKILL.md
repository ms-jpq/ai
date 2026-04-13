---
description: Survey the codebase for a topic. Catalog every pattern, idiom, and convention found. Compare against existing rules and memory. Report discrepancies — don't write rules.
---

# Mine

Read the codebase for a topic and extract what's actually there. Compare against documented rules. Report findings — never write or update rules.

## Input

Argument is a topic (e.g., "makefile", "shell", "python"). Match to an existing rules file if one fits.

## Process

### 1. Read

Find all source files relevant to the topic. Exclude generated directories (`node_modules/`, `.venv/`, `var/tmp/`). Read every file — don't sample.

### 2. Reflect

Catalog every pattern, idiom, convention, and structural choice you observe. Note what's deliberate — recurring patterns reflect intent.

Compare what you found against what's already documented:

- **Discrepancies** — rules say X, code does Y.
- **Undocumented** — pattern absent from rules.
- **Speculative** — rule not reflected in code.

Cite files and lines. Rank by prevalence. Report what you found.
