---
name: op-mechanism-alignment
description: Cultivate a minimal basis of mechanisms that covers salient concerns.
---

# Mechanism Alignment

- A mechanism describes how an effect is produced. Structural components, such as modules or services, implement mechanisms.

  - One mechanism may span several components, and one component may implement several mechanisms.

  - Generalizing or splitting a mechanism need not merge or split its implementing components.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Mechanisms:** A minimal basis of causal processes addressing salient concerns.

- **Coverage:** Which mechanisms address each concern, through what effects and under what conditions, including uncovered concerns.

---

## Observation (Input)

_State the input categories and their roles._

- **Concerns:** What the mechanisms must address, ranked by salience.

- **Mechanisms:** Existing and proposed causal processes to assess.

- **Coverage:** Claimed effects and operating conditions linking mechanisms to concerns.

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

- Derive each mechanism's observable effects when its preconditions hold and when they fail, including adverse effects.

- Predict which concerns remain covered by a shared mechanism and which require distinct ones.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived effects against the system and its intended model.

  - Test shared mechanisms across their mapped concerns, including cases where satisfying one could impair another.

- Specialize, split, or replace a mechanism when evaluation exposes incompatible effects or preconditions.

- Retain the smallest tested mechanism basis that preserves required coverage.

- Revisit the mechanism mapping when changing the mechanism does not resolve the gap.

---

- Use @../op-topology-recomposition/SKILL.md when a mechanism requires different component boundaries, placement, or connections.

- Use @../op-problem-framing/SKILL.md during induction when the concerns or their priorities need revision.
