# JQ Scripting Guidelines

- When creating standalone `jq` scripts, always use the following shebang

```jq
#!/usr/bin/env -S -- jq --exit-status --from-file
```
