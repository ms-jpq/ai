---
paths:
  - "*.gvpr"
---

# Gvpr

## Defaults

- Start standalone `gvpr` scripts with:

```gvpr
#!/usr/bin/env -S -- gvpr -c -f
```

- To output the selected subgraph instead of the modified input graph, omit `-c`:

```gvpr
#!/usr/bin/env -S -- gvpr -f
```
