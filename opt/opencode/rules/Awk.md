---
paths:
  - "*.awk"
---

# Awk

- Standalone `awk` scripts get this shebang:

```awk
#!/usr/bin/env -S -- awk -f
```

- Function-local (non-input) variables are named with the `L_` prefix.
