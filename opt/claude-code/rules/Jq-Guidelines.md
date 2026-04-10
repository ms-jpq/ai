# JQ Scripting Guidelines

- When creating standalone `jq` scripts, always use the follow shebang

```jq
#!/usr/bin/env -S -- jq --exit-status --from-file
```
