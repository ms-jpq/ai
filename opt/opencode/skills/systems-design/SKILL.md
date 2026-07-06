---
name: systems-design
description: Design or refine software architecture.
---

Use @../refactor/SKILL.md.

# Decompose

- Model the system as a sequence of stages from input to output.

- Decompose along stage boundaries.

- Define one complete domain type file per stage.

# Separate

- Make each stage either a transform or an effect.

- Place persistent state at stage boundaries: modules, queues, or databases.

# Specify

- Use generic interfaces at stage boundaries.

- Use the most specific concrete implementation within each stage.

- Make every component testable through direct calls and return values.
