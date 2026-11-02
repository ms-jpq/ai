---
name: converge
description: Seek the simplest system model sufficient for its purpose, reasoning through revisions toward a stable fixed point.
---

# Convergence

- Follow @./references/Operator-Protocol.md for explicit inputs, outputs, and Peircean reasoning.

- `system model + optional(information) → revised system model`.

---

## Artifact (Output)

_State the intended properties declaratively._

- The revised system model has fewer redundant distinctions, relationships, and mechanisms while covering its purpose and constraints.

- Missing components are supplied and unnecessary complexity is removed.

- Further application under unchanged inputs yields no justified simplification or correction.

---

## Observation (Input)

_State the input categories and their roles._

- `system model + optional(information) → revised system model`.

---

## Operators

- Each operator performs its own reasoning cycle over explicit inputs and outputs. Compose them by passing one operator's output to another.

- Keep operators as a basis of transformations with distinct primary effects.

- Operators may invoke other operators, not higher-level skills. Higher-level skills compose these building blocks and may reuse one another.

- Apply and re-enter these transformations in order as evidence warrants:

0. **Purpose Formation:** Form and revise the system purpose that guides the remaining operators.

   - @../op-purpose-formation/SKILL.md

1. **Problem Framing:** Classify a system's obstructing problems and prioritize their concerns.

   - @../op-problem-framing/SKILL.md

2. **Topology Recomposition:** Iteratively resolve structural problems in a concern hierarchy.

   - @../op-topology-recomposition/SKILL.md

3. **Conceptual Synthesis:** Give consistent names that semantically compress ideas.

   - @../op-conceptual-synthesis/SKILL.md

4. **Mechanism Alignment:** Cultivate a minimal basis of mechanisms that covers salient concerns.

   - @../op-mechanism-alignment/SKILL.md
