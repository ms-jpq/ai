# Project Workspace

Layout:

- both `.exp/` and `.notes/` are gitignored, and are themselves git repos.

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
|   |-- worktree/
|   `-- <topic>/
`-- ...
```

## Worktree Symlinks

- `.exp/` → `<main>/.exp/` — one shared tool pool across all worktrees.

- `.notes/` → `<main>/.notes/worktrees/<name>/` — per-worktree, survives teardown.

- Dead worktrees are marked with a tomb stone of `<main>/.notes/worktrees/<name>/DEAD.md`
