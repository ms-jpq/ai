---
description: Update or create a rules file from findings in conversation context. Tighten what's vague, correct what's drifted, add what's missing. Pair with /mine to gather findings first.
---

# Refine

Take findings — from `/mine`, conversation context, or user input — and codify them into a rules file. Tighten what's vague, correct what's drifted, add what's missing.

## Input

Argument is a topic (e.g., "makefile", "shell", "python"). Match to an existing rules file if one fits. Create one if not.

## Process

If no findings are present in conversation context, run `/mine` for the topic first.

Ask before writing. Present proposed changes and wait for approval.

### Write

Create or update the rules file. Each rule:

- Leads with the what, not the why. One idea per bullet.

- Uses generic examples. No project-specific names, paths, or dependencies.

- Redirects behavior. Cut rules a competent default already satisfies.

- Is concise. Cut filler and redundant explanations.

### Verify

Re-read what you just wrote as a cold reader — no conversation history, no memory, no prior context.

For each rule, ask:

- Could this be misread?

- Does it under-specify?

- Would two competent readers produce different code from it?

Flag every ambiguity. Revise. Re-read again. Repeat until a pass produces zero flags.

## Standard

- The rules file is the sole carrier of intent.

- A fresh Claude instance reading only the rules file must produce the same code the user would write.

- If a rule can be read two ways, it will be.

- Stop when every rule has exactly one interpretation.
