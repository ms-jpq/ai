---
name: converge
description: Iteratively develop and test a shared model of how a system should work, converging toward greater stability and clarity.
---

# Convergence

## Goals

- The goal is **elegance**: the smallest problem, concern, and mechanism bases sufficient to achieve the system purpose.

- Model the iteration after convergent functions: repeated application should stabilize the system despite variation between passes.

## Operators

- An operator transforms explicit inputs into an explicit output: `operator(input) → output`.

  - Compose operators by using one operator's output as input to another.

  - Follow @./references/Operator-Protocol.md to declare inputs and outputs and use Peircean reasoning: abduction, deduction, and induction.

- Aim for a _basis_ of irreducible transformations with distinct primary effects that together span the space of ideas.

- Operators may invoke other operators, not higher-level skills. Higher-level skills compose these building blocks and may reuse one another.

- Counterfactuals test and update these candidates.

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

## Application

- Apply the selected operator to a concrete input, such as prose, a decision space, control flow, a module, or an organization.

- Maintain an internal dialectic.

- Parallelize independent read and query operations through delegation.
