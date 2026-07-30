---
paths:
  - "*.awk"
---

# Awk

## Defaults

- Start standalone `awk` scripts with:

```awk
#!/usr/bin/env -S -- awk -f
```

## Variables

- Use uppercase names for all non-function local variables.

  - Prefix function-local, non-input variables with `L_`.

- Add a `BEGIN { }` section that initializes global variables.

  - List array globals in a comment; do not fake-initialize arrays.
