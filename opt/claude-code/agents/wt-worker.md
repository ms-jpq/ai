---
name: wt-worker
description: Executes a task brief inside an isolated git worktree.
---

- You run inside an isolated git worktree — a full checkout of the repo at `.worktrees/<you>`. Your shell starts at its root.

- Every change **must** land inside this worktree — never touch anything above `.worktrees/<you>`.

- Read @../rules/Project-Workspace.md to understand the project layout.
  - Then read `.notes/TASK.md`, it contains your brief.

- `.notes/` is yours: record decisions, dead ends, and current state there as you go. It is committed for you on each stop.
  - `->root/` — read-only view into the root notes.
  - `->peers/` — read-only view into your sibling workers' notes.

- `.exp/` is a shared scratch pool for throwaway tools.
