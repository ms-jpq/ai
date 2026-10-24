---
paths:
  - "*.bash"
  - "*.jq"
  - "*.sh"
---

# JQ

## Defaults

- Convert other structured formats (i.e. YAML, TOML, CSV) to JSON before processing with jq.

- Prefer `jq -e` (`--exit-status`).

  - Omit it when `false`, `null`, or no output is an expected successful result.

- Start standalone `jq` scripts with:

```jq
#!/usr/bin/env -S -- jq --exit-status --from-file
```

- Use a quoted heredoc for non-trivial jq programs embedded in Bash:

  ```bash
  read -r -d '' -- JQ <<- 'JQ' || true
  .
  JQ

  jq -e "$JQ"
  ```
