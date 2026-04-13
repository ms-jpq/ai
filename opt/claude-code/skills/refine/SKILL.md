---
description: Sharpen understanding of a topic by re-reading the codebase against existing rules and memory. Tighten, correct, or extend the rules file so future sessions stay accurate.
---

# Refine

Re-examine the codebase for a topic and measure what you find against the current rules file, memory, and context. Tighten what's vague, correct what's drifted, add what's missing.

## Input

Argument is a topic (e.g., "makefile", "shell", "python"). Match to an existing rules file if one fits. Create one if not.

## Process

### 1. Read

Find all source files relevant to the topic. Exclude generated directories (`node_modules/`, `.venv/`, `var/tmp/`). Read every file — don't sample.

### 2. Reflect

Catalog every pattern, idiom, convention, and structural choice you observe. Note what's deliberate — recurring patterns reflect intent.

Compare what you found against what's already documented:

- **Discrepancies** — rules say X, code does Y.
- **Undocumented** — pattern absent from rules.
- **Speculative** — rule not reflected in code.

Cite files and lines. Rank by prevalence. Report what you found and ask before writing.

### 3. Codify

Create or update the rules file. Then compress — repeat until stable:

- **Rules** lead with the what, not the why. One idea per bullet.
- **Examples** are generic. No project-specific names, paths, or dependencies.
- **Cut the obvious.** Only keep rules that redirect behavior.
- **Language** is concise. Cut filler and redundant explanations.
