---
name: open
description: Open focused files, directories, and links only when explicitly invoked by the user.
---

- Invoke this skill only when the user calls `/open` or explicitly asks to open something.

- Open what is currently in focus, not the entire session history.

- Open exactly the provided arguments, if any.

- Otherwise, select recent items from this turn's immediate context: files just edited, paths just read, or URLs just discussed.

  - Prefer recency over completeness.

  - Infer at most three items.

- Make each path absolute.

- For files and directories invoke `tmux-edit` with multiple arguments: `tmux-edit FILE|DIR [FILE|DIR]...`

  - `tmux-edit` uses `nvim` as `$EDITOR`, so line jumps work: `tmux-edit '+<lineno>' '<filename>'`

- For links invoke `$BROWSER` with multiple arguments: `$BROWSER LINK [LINK]...`
