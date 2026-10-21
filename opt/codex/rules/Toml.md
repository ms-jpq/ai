---
paths:
  - "*.toml"
---

# TOML

## Defaults

- Add `#:schema <schema-url>`.

---

## Conversion

- Use Taplo to convert TOML to JSON.

  ```bash
  taplo get --output-format json < '<input>.toml' > '<output>.json'
  ```
