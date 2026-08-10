---
name: open
description: Open focused files, directories, and links only when explicitly invoked by the user.
---

Invoke this skill only when the user explicitly calls `/open` or otherwise explicitly asks to open something.

Open what is currently in focus, not the entire session history.

- If arguments are provided, that is the set. Open exactly those.

- Otherwise, default to recently mentioned items from this turn's immediate context: files just edited, paths just read, URLs just discussed. Recency over completeness.

- Cap at 3 even when the recent set is larger. If there are too many candidates, ask before opening.

- Make each path absolute.

- For files and directories invoke `tmux-edit` with multiple arguments: `tmux-edit FILE|DIR [FILE|DIR]...`

  - `tmux-edit` uses `nvim` as `$EDITOR`, so line jumps work: `tmux-edit '+<lineno>' '<filename>'`

- For links invoke `$BROWSER` with multiple arguments: `$BROWSER LINK [LINK]...`
