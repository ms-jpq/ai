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

- Use uppercase names for global variables.

- Add a `BEGIN { }` section that initializes global variables.

  - List array globals in a comment; do not fake-initialize arrays.

- Prefix function-local, non-input variables with `L_`.
