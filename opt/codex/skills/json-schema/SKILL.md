---
name: json-schema
description: Draft and evolve example-first JSON Schema contracts.
---

# JSON Schema

Use @../op-situation-modeling/SKILL.md to identify required and forbidden domain states.

Use @../op-terminology-distillation/SKILL.md to name recurring fields and concepts precisely.

## Model

- Identify the domain's entities, fields, types, required states, exclusions, and invariants.

- Keep uncertain constraints explicit; do not infer them only from a positive example.

## Draft

- Create three sibling files:

  - Start from `references/<domain>.schema.yml` and `references/<domain>.schema.example.yml`.

  - `<domain>.schema.yml`: JSON Schema expressed as YAML.

  - `<domain>.schema.example.yml`: an accepted instance whose first line is:

    ```yaml
    # yaml-language-server: $schema=./<domain>.schema.yml
    ```

- Make the invalid fixture violate one intended constraint, such as a missing required field or an extra property.

## Validate

- Run the existing linter directly while drafting:

  ```sh
  opt/codex/libexec/linters/json-schema.sh <domain>.schema.example.yml
  opt/codex/libexec/linters/json-schema.sh <domain>.schema.invalid.yml
  ```

- The accepted fixture must exit successfully. The invalid fixture must fail with the intended diagnostic.

- The normal format-and-lint hook repeats this validation for changed schema-declaring data files.

## Iterate

- Revise the schema and both fixtures together when the domain changes.

- Preserve valid behavior unless an explicit domain change requires a breaking schema change.
