# Project Workspace

## Root Layout

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

## Worktree Layout

```
./
|-- .exp/
|   `-- ...
|-- .notes/
|   |-- LIVE_CONTEXT.md
|   |-- @peers/
|   |-- @root/
|   `-- <topic>/
`-- ...
```

---

## Worktree Symlinks

- `.exp/` → `<root>/.exp/`: shared tool pool across worktrees.

- `.notes/` → `<root>/.notes/worktrees/<name>/`: per-worktree notes that survive teardown.

- `.notes/@root/` → `<root>/.notes/`: root notes.

- `.notes/@peers/` → `<root>/.notes/worktrees/`: sibling worktree notes.
