---
name: json-schema
description: Draft and evolve example-first JSON Schema contracts.
---

# JSON Schema

Use @../op-situation-modeling/SKILL.md to identify required and forbidden domain states.

Use @../op-terminology-distillation/SKILL.md to name recurring fields and concepts precisely.

## Draft

- Create the sibling files, see `references/*.yml`

- Take care to ensure the `# yaml-language-server: $schema=...` is updated.

## Model

- Identify the domain's entities, fields, types, required states, exclusions, and invariants.

## Validate

- Run the existing linter directly while drafting:

  ```sh
  opt/codex/skills/json-schema/scripts/lint.sh <domain>.schema.example.yml
  opt/codex/skills/json-schema/scripts/lint.sh <domain>.schema.invalid.yml
  ```

- The accepted fixture must exit successfully. The invalid fixture must fail with the intended diagnostic.

- The normal format-and-lint hook repeats this validation for changed schema-declaring data files.

## Iterate

- Revise the schema and both fixtures together when the domain changes.

- Preserve valid behavior unless an explicit domain change requires a breaking schema change.
