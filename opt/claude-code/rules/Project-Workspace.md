# Project Workspace

Root Layout:

```
./
|-- .exp/
|   `-- ...
|-- .notes/
|   |-- design/
|   |-- plans/
|   |-- research/
|   |-- tasks/
|   |-- worktrees/
|   `-- <topic>/
|-- .worktrees/
|   `-- <name>/
`-- ...
```

---

Worktree Layout:

```
./
|-- .exp/
|   `-- ...
|-- .notes/
|   |-- TASK.md
|   |-- ->peers/
|   |-- ->root/
|   `-- <topic>/
`-- ...
```

---

## Worktree Symlinks

- `.exp/` → `<root>/.exp/` — one shared tool pool across all worktrees.

- `.notes/` → `<root>/.notes/worktrees/<name>/` — per-worktree, survives teardown.

- `.notes/->root/` → `<root>/` — the root worktree.

- `.notes/->peers/` → `<root>/.notes/worktrees/` — the sibling notes pool.
