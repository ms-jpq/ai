---
name: converge
description: Seek the simplest system model sufficient for its purpose, reasoning through revisions toward a stable fixed point.
---

# Convergence

- Follow @./references/Operator-Protocol.md for explicit inputs, outputs, and Peircean reasoning.

---

## Artifact (Output)

_State the intended properties declaratively._

- A reasoned system model built from a minimal sufficient basis of concepts, parts, relationships, and mechanisms.

  - Its purpose and constraints are connected to the concerns, outcomes, and means of achieving them.

- Rationale and available evidence supporting the model, with unresolved assumptions and contradictions explicit.

---

## Observation (Input)

- Read the system or its representation, intended purpose, constraints, current model, and available evidence.

- Identify what the model cannot explain or achieve, and where inconsistent concepts, coupled responsibilities, or overlapping mechanisms make it difficult to use.

- Parallelise independent read and query operations through delegation.

---

## Abduction

_Devise an explanation for observations._

- Maintain an internal dialectic: propose and compare revisions to the system's purpose, problem framing, structure, concepts, or mechanisms.

- Use the relevant operators below to develop missing components and reduce redundant ones.

  - Allow temporary increases in detail or parts when they expose a simpler organisation.

- Revisit purpose or boundaries when commitments or intended outcomes conflict. Do not silently weaken the purpose to make the model smaller.

---

## Deduction

_Derive consequences of the explanation._

- Derive what each candidate implies for the system: what counts as success, which concerns matter, what concepts include or exclude, and how parts and mechanisms produce outcomes.

  - Include cases where commitments conflict, assumptions fail, or effects interfere.

- For each addition, removal, merge, or generalisation, derive its effect on required outcomes, constraints, distinctions, and concern coverage.

- Compare the context, coordinated changes, and verification effort required by current and proposed models for the same change.

- Identify cases where candidates imply different decisions, classifications, or outcomes.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Assess the derived consequences through worked scenarios and counterexamples, using observations or experiments where available.

  - Distinguish reasoned conclusions from empirically tested claims.

- First assess whether each candidate satisfies the relevant operator's retention criteria. Add necessary complexity when the current model is insufficient.

  - Among sufficient candidates, prefer the one requiring less effort to understand, change, and verify. Fewer components alone do not establish improvement.

- Record unresolved assumptions or contradictions and re-enter the affected operators when findings change their inputs.

- Treat the model as provisionally stable when another pass with unchanged purpose, constraints, and evidence yields no justified revision.

  - Investigate oscillating choices rather than repeatedly rewriting them. Stability alone does not establish correctness or a globally simplest model.

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
