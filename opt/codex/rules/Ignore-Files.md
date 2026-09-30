---
paths:
  - ".fdignore"
  - ".gitignore"
  - ".gitkeep"
  - ".ignore"
  - ".rgignore"
---

# Ignore Files

- Prefer one consolidated ignore file per tool at the project root over scattered ignore files.

- Symlink ignore files to a shared canonical file when their patterns and tool semantics permit it.

- Preserve empty directories with an empty `.gitignore`, not `.gitkeep`.

- To ignore a directory's contents while retaining its placeholder, use `.gitignore` containing:

  ```gitignore
  *
  !.gitignore
  ```
