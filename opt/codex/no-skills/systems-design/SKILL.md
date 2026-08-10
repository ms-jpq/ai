---
name: systems-design
description: Design or refine software architecture.
---

Use @../../skills/op-topology-modeling/SKILL.md.

Use @../../skills/op-topology-reshaping/SKILL.md before choosing an architecture.

# Decompose

- Model the system as a sequence of stages from input to output.

- Split stages where data changes meaning, ownership, or crosses an effect boundary.

- Define explicit input and output types for each stage.

# Separate

- Make each stage either a transform or an effect.

- Place persistent state behind stage boundaries: files, queues, or databases.

# Specify

- Define stage boundaries as contracts with substitutable implementations.

- Use the most specific concrete implementation within each stage.

- Keep transform stages referentially transparent.

- Test effect stages through substitutable boundary implementations.

---

# Generalize

- Identify the generic problem underneath the specific request.

- Build a small library for the generic problem.

- Test the generic library directly; generic tests are usually smaller and clearer.

- Solve the specific problem by adapting inputs and outputs around the library.
