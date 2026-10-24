---
paths:
  - "*.bash"
  - "*.sed"
  - "*.sh"
---

# Sed

## Defaults

- Start standalone `sed` scripts with:

```sed
#!/usr/bin/env -S -- sed -E -f
```

- Use a quoted heredoc for non-trivial sed programs embedded in Bash:

  ```bash
  read -r -d '' -- SED <<- 'SED' || true
  p
  SED

  sed -E -n -e "$SED"
  ```
