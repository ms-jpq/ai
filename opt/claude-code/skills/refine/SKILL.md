---
description: Update or create a rules file from findings in conversation context. Tighten what's vague, correct what's drifted, add what's missing. Pair with /mine to gather findings first.
---

# Refine

Take findings — from `/mine`, conversation context, or user input — and codify them into a rules file. Tighten what's vague, correct what's drifted, add what's missing.

## Input

Argument is a topic (e.g., "makefile", "shell", "python"). Match to an existing rules file if one fits. Create one if not.

## Process

If no findings are present in conversation context, run `/mine` for the topic first. Ask before writing.

Create or update the rules file. Then compress — repeat until stable:

- **Rules** lead with the what, not the why. One idea per bullet.
- **Examples** are generic. No project-specific names, paths, or dependencies.
- **Cut the obvious.** Only keep rules that redirect behavior.
- **Language** is concise. Cut filler and redundant explanations.
