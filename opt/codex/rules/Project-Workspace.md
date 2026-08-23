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

---

## Worktree Records

- `.notes/worktrees/<name>/LIVE_CONTEXT.md` is the worker's durable brief.

- `.worktrees/<name>/` is the worker's ephemeral code checkout.
