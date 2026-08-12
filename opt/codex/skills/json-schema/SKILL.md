---
name: json-schema
description: Draft and evolve example-first JSON Schema contracts.
---

# JSON Schema

## Draft

- Create the sibling files, see `references/`

- Take care to ensure the `# yaml-language-server: $schema=...` is updated.

## Validate

```bash
${SKILL_DIR}/libexec/lint.ts domain.schema.yml
${SKILL_DIR}/libexec/lint.ts domain.schema.example.yml
```

## Installation

```bash
npm install --prefix ${SKILL_DIR}
```
