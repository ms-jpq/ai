---
description: Iteratively distill codebase findings into a rules file through conversation. Propose, ask, revise, repeat until unambiguous. Pair with /mine to gather findings first.
---

# Refine

Distill findings into a rules file through iterative conversation with the user. Never write without asking. Never stop asking until every rule is unambiguous.

## Input

Argument is a topic (e.g., "makefile", "shell", "python"). Match to an existing rules file if one fits. Create one if not.

If no findings are present in conversation context, run `/mine` for the topic first.

## Loop

Each pass:

1. **Propose** — present candidate rules or changes. Explain what each captures and why it matters.

2. **Ask** — surface ambiguities, trade-offs, and gaps. Ask the user to resolve them. Do not guess.

3. **Revise** — incorporate the user's answer. Tighten language. Cut what a competent default already satisfies.

4. **Check** — re-read as a cold reader. For each rule, ask:
   - Could this be misread?

   - Does it under-specify?

   - Would two readers produce different output from it?

   If any answer is yes, go to step 1 with the flagged rules.

Repeat until a pass produces zero flags.

## Rules quality

- One idea per bullet. Lead with the what.

- Examples are generic — no project-specific names, paths, or dependencies.

- Cut filler. Cut obvious. Only keep what redirects behavior.

## Standard

- The rules file is the sole carrier of intent.

- A fresh Claude instance reading only the rules file must produce the same output the user would write.

- If a rule can be read two ways, it will be.

- Stop when every rule has exactly one interpretation.
