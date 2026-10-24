---
paths:
  - "*.awk"
  - "*.bash"
  - "*.sh"
---

# Awk

## Defaults

- Start standalone `awk` scripts with:

```awk
#!/usr/bin/env -S -- awk -f
```

- Use a quoted heredoc for non-trivial awk programs embedded in Bash:

  ```bash
  read -r -d '' -- AWK <<- 'AWK' || true
  { print }
  AWK

  awk -- "$AWK"
  ```

## Variables

- Use uppercase names for all non-function local variables.

  - Prefix function-local, non-input variables with `L_`.

- Add a `BEGIN { }` section that initializes global variables.

  - List array globals in a comment. Do not fake-initialize arrays.
