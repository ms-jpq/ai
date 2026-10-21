---
paths:
  - "*.yml"
  - "*.yaml"
---

# YAML

## Defaults

- Add `# yaml-language-server: $schema=<schema-url>`.

- Prefer `.yml` to `.yaml`.

---

## Conversion

- Use gojq to convert YAML to JSON.

  ```bash
  gojq --yaml-input '.' < '<input>.yml' > '<output>.json'
  ```
