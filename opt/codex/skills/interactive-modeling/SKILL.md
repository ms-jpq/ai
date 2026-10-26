---
name: interactive-modeling
description: Interactively evolve a domain model and reconcile it with a queryable, checkable representation under source control.
---

# Interactive Modelling

- Preserve the shared model and its stricter representation under source control.

- Use @../converge/SKILL.md to revise the shared model when ambiguity, surprising results, or failed checks expose gaps in understanding.

- Use @../mat/SKILL.md when tables clarify the model's dimensions and relationships.

- Use @../fold/SKILL.md to incorporate new observations and decisions into the existing model.

- Use @../bisync/SKILL.md to reconcile the representations when their claims diverge.

---

## Artifact (Output)

- An evolving domain model and a corresponding stricter representation, with reproducible translation and checks.

- Explicit mappings, unresolved questions, and translation gaps sufficient to interpret their correspondence.

---

## Observation (Input)

- Read the current model, new observations, and relevant revision history.

- Identify the questions the model must answer and the distinctions its representations currently lose.

---

## Abduction

_Devise an explanation for observations._

- Propose revisions to the entities, relationships, and constraints that explain the observations.

- Choose a stricter representation and map the shared model's identities and notation into it.

  - Keep unknowns explicit and identify prose whose meaning requires interpretation before translation.

---

## Deduction

_Derive consequences of the explanation._

- Derive representative queries, expected answers, and checks that would expose missing or contradictory claims.

- Specify which facts and relationships must agree across representations, including changes from the previous revision.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Update the shared model interactively and translate at coherent checkpoints before relying on the stricter model's answers.

- Compare decoded source data with corresponding model facts and query results.

  - Check the declared correspondence rather than raw formatting. Distinguish derived conclusions from directly represented facts.

  - For Markdown tables, use the JSON extraction in @../mat/SKILL.md.

- Reconcile discrepancies and feed useful findings back into the shared model. Preserve unmapped content and unresolved conflicts.

- Review the source-control diff for lost requirements or changed meanings, and retain the translation rules and checks needed to reproduce the revision.

---

## Representations

- For Prolog, read `./references/prolog.md`.
