---
name: rec
description: Model a domain using GNU Recutils, with explicit types, relationships, and constraints.
---

See description.

- Keep record descriptors in `defs/*.rec` and records in `data/*.rec`.

  ```tree
  ./
  ├── defs/
  │   └── <type>.rec
  └── data/
      └── <type>.rec
  ```

  - Reference the descriptor from each data file using a relative path:

    ```rec
    %rec: <type> defs/<type>.rec
    ```

  - Run commands from the project root. Relative descriptor paths resolve against the working directory.

- Run validation manually after changing records or their descriptors:

  ```bash
  env -C '<ROOT>' recfix --check -- 'data/<type>.rec'
  ```

  - When a descriptor changes, check every data file that references it.

- [GNU Recutils manual](https://www.gnu.org/software/recutils/manual/recutils.html).
