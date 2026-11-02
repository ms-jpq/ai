---
name: op-mechanism-alignment
description: Cultivate a minimal basis of mechanisms that covers salient concerns.
---

# Mechanism Alignment

- Use @../op-topology-recomposition/SKILL.md when a mechanism requires different component boundaries, placement, or connections.

- Use @../op-problem-framing/SKILL.md during induction when the concerns or their priorities need revision.

- A mechanism describes how an effect is produced. Structural components, such as modules or services, implement mechanisms.

  - One mechanism may span several components, and one component may implement several mechanisms.

  - Generalizing or splitting a mechanism need not merge or split its implementing components.

---

## Artifact (Output)

_State the intended properties declaratively._

- A minimal basis of named mechanisms that covers salient concerns.

  - Each mechanism produces effects that address its mapped concerns under stated assumptions.

  - Shared mechanisms preserve coverage across their concerns without incompatible effects or preconditions.

  - Redundant mechanisms are removed where testing supports preserved coverage.

- An explicit many-to-many concern-to-mechanism mapping.

  - Shared mappings state the causal path that covers their concerns.

  - Mappings include expected effects, preconditions, and possible adverse effects.

- An explicit gap for each salient concern without an understood mechanism.

---

## Observation (Input)

_State the input categories and their roles._

- Framed concerns and priorities define the coverage sought.

- Intended, operating, and proposed mechanisms provide candidates for reuse or revision.

- Existing coverage claims, expected effects, assumptions, and evidence provide the baseline for assessing mechanisms and discovering gaps.

- The implementation and its intended mechanism model provide distinct accounts of actual and intended effects.

---

## Abduction

_Devise an explanation for observations._

- Explore candidate mechanisms by reusing, adapting, combining, or inventing them.

  - Explain how each candidate would produce its intended effects under the proposed assumptions.

- Generalize a mechanism when one causal path addresses several concerns.

- Specialize or split a mechanism when its concerns require incompatible effects or preconditions.

---

## Deduction

_Derive consequences of the explanation._

- Derive observable outcomes when each mapping's preconditions hold and when they fail, including adverse effects.

- Predict which concerns remain covered by a shared mechanism and which require distinct ones.

- Predict what evidence would require the mechanism, its mapping, or its concern priority to change.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived effects against the system and its intended model.

  - Test shared mechanisms across their mapped concerns, including cases where satisfying one could impair another.

- Retain a mechanism only when its effects address its mapped concerns under its stated assumptions.

- Specialize, split, or replace a mechanism when evaluation exposes incompatible effects or preconditions.

- Retain the smallest tested mechanism basis that preserves required coverage.

- Revisit the mechanism mapping when changing the mechanism does not resolve the gap.
