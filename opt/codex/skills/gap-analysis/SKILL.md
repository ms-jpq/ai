---
name: gap-analysis
description: Discover consequential omissions relative to a purpose, reassessing coverage without introducing unnecessary scope.
---

# Gap Analysis

- Apply to concerns, questions, features, mechanisms, outcomes, or another level of the system.

- Use @../op-purpose-formation/SKILL.md when the purpose or scope needs clarification.

- Use @../op-problem-framing/SKILL.md when a suspected omission requires revising the problem frame or its concerns.

## Artifact (Output)

- Prioritized gaps, each linked to the purpose, its missing coverage, and the consequence of leaving it unresolved.

- Explicit uncertainty where available information cannot establish whether coverage is missing.

## Observation (Input)

- Read the purpose, scope, constraints, and material whose coverage is being examined.

- Identify what is already covered, deliberately excluded, unresolved, or previously dismissed and why.

## Abduction

_Devise an explanation for observations._

- Propose omissions that could obstruct the purpose, considering relevant situations, dependencies, and failure conditions beyond those already represented.

- Explain why each candidate is missing coverage rather than another name for something present or a preference for a different solution.

- Consider whether existing provisions cover the need indirectly. Use @../op-mechanism-alignment/SKILL.md when that coverage depends on an unclear causal path.

## Deduction

_Derive consequences of the explanation._

- Predict what becomes impossible, unreliable, or materially worse if the suspected gap remains.

- Identify a case or observation that would distinguish missing coverage from adequate coverage.

- Describe the coverage needed without assuming a particular implementation or expanding the purpose.

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Check the predictions against the actual material, relevant cases, and available evidence.

- Discard duplicates, already-covered needs, and additions without a consequential connection to the purpose.

- Prioritize supported gaps by their consequences, distinguishing them from unverified possibilities.

- Return no gaps when none are supported, without treating that result as proof of completeness.

## Application

- Re-invoke `gap-analysis` to reassess coverage, using prior findings to explore overlooked areas rather than repeat unresolved items or manufacture new ones.

- Reconsider dismissed gaps when their premises change. Report newly found or revised gaps and material uncertainties.

- The caller chooses how to address findings. A gap does not itself authorize new features, implementation, or scope changes.
