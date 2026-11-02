---
name: open
description: Open focused files, directories, and links only when explicitly invoked by the user.
---

# Open

- Invoke this skill only when the user calls `/open` or explicitly asks to open something.

- Open exactly the provided arguments, if any.

- Otherwise, select at most three recent items from the immediate context: files just edited, paths just read, or URLs just discussed.

- For files and directories, invoke `tmux-edit`: `tmux-edit FILE|DIR [FILE|DIR]...`

  - Make each path absolute.

  - `tmux-edit` uses `nvim` as `$EDITOR`, so line jumps work: `tmux-edit '+<lineno>' '<filename>'`

- For links, invoke `$BROWSER`: `$BROWSER LINK [LINK]...`
