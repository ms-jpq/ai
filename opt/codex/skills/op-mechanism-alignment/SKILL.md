---
name: op-mechanism-alignment
description: Cultivate a minimal basis of mechanisms that covers salient concerns.
---

# Mechanism Alignment

- Use @../op-topology-recomposition/SKILL.md when a mechanism requires different part boundaries, placement, or connections.

## Artifact (Output)

- A minimal basis of named mechanisms that covers salient concerns.

  - A concern may require several mechanisms.

  - A mechanism may cover several concerns.

- An explicit concern-to-mechanism mapping.

  - Shared mappings state the causal path that covers their concerns.

  - Mappings include expected effects, preconditions, and possible adverse effects.

- An explicit gap for each salient concern without an understood mechanism.

## Observation (Input)

- Take the framed concerns, priorities, and evidence as inputs.

- Record mechanisms already intended, operating, or proposed.

- Record each concern's current coverage, expected effect, assumptions, and unknowns.

- Keep an implementation distinct from its intended mechanism model.

  - A mechanism describes how an effect is produced, not a part boundary. One mechanism may span parts, and one part may support several mechanisms.

## Abduction

_Devise an explanation for observations._

- Explore candidate mechanisms by reusing, adapting, combining, or inventing them.

- Explain how each candidate would produce its intended effects under the proposed assumptions.

- Generalize a mechanism when one causal path addresses several concerns, without assuming their parts must merge.

- Specialize or split a mechanism when its concerns require incompatible effects or preconditions, without assuming separate part boundaries.

## Deduction

_Derive consequences of the explanation._

- Derive observable outcomes when each mapping's preconditions hold and when they fail, including adverse effects.

- Predict which concerns remain covered by a shared mechanism and which require distinct ones.

- Predict what evidence would require the mechanism, its mapping, or its concern priority to change.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the derived effects against the system and its intended model.

- Retain a mechanism only when its effects address its mapped concerns under its stated assumptions.

- Test shared mechanisms across their mapped concerns, including cases where satisfying one could impair another.

- Specialize, split, or replace a mechanism when evaluation exposes incompatible effects or preconditions.

- Prefer the smallest tested mechanism basis that preserves required coverage.

  - Remove a mechanism when testing confirms that its removal preserves required coverage under the stated assumptions.

- Revisit the mechanism mapping when changing the mechanism does not resolve the gap. Use @../op-problem-framing/SKILL.md when the concerns or their priorities need revision.
