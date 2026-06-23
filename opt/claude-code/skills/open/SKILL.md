---
description: Open the files, directories, and links relevant to the current context.
---

Open what's currently in focus — not the entire session history.

- If arguments are provided, that is the set. Open exactly those.

- Otherwise, default to recently mentioned items from this turn's immediate context: files just edited, paths just read, URLs just discussed. Recency over completeness.

- Cap at 3 even when the recent set is larger. if there are too many canddiates, ask before opening.

- Make each path absolute.

- For files and directories invoke `tmux-edit` with multiple arguments: `tmux-edit FILE|DIR [FILE|DIR]...`

- For links invoke `$BROWSER` with multiple arguments: `$BROWSER LINK [LINK]...`
