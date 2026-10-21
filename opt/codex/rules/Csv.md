---
paths:
  - "*.csv"
  - "*.tsv"
---

# CSV and TSV

---

## Conversion

- Use Miller to convert CSV or TSV to JSON with type inference disabled.

  ```bash
  mlr --icsv --ojson --infer-none cat < '<input>.csv' > '<output>.json'

  mlr --itsv --ojson --infer-none cat < '<input>.tsv' > '<output>.json'
  ```
