# Project Workspace

Layout:

```
./
|-- .exp/
|   |-- .git/
|   `-- ...
|-- .notes/
|   |-- .git/
|   |-- design/
|   |-- plan/
|   |-- research/
|   |-- worktrees/
|   `-- <topic>/
`-- ...
```

## Worktree Symlinks

- `.exp/` → `<main>/.exp/` — one shared tool pool across all worktrees.

- `.notes/` → `<main>/.notes/worktrees/<name>/` — per-worktree, survives teardown.

- Dead worktrees are marked with a tomb stone of `<main>/.notes/worktrees/<name>/DEAD.md`
