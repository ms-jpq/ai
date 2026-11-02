---
name: interactive-modeling
description: Interactively evolve a domain model and reconcile it with a queryable, checkable representation under source control.
---

# Interactive Modelling

- Use @../converge/SKILL.md to revise the shared model when ambiguity, surprising results, or failed checks expose gaps in understanding.

- Use @../fold/SKILL.md to incorporate new observations and decisions into the existing model.

- Use @../bisync/SKILL.md to reconcile the representations when their claims diverge.

- Use @../mat/SKILL.md when tables clarify the model's dimensions and relationships.

---

## Artifact (Output)

_State the intended properties declaratively._

- Mapped facts and relationships agree across the shared model and its stricter representation, except for explicit unresolved discrepancies.

- Queries and checks address the model's questions and possible gaps or contradictions.

  - Results trace to stated facts and distinguish them from derived conclusions.

- Translation preserves required distinctions.

  - Unmapped content remains available, with unknowns, interpretation choices, and translation gaps explicit.

- Both representations, their mappings, and reproducible checks remain under source control.

---

## Observation (Input)

_State the input categories and their roles._

- Any existing model and corresponding representation provide claims and mappings to revise.

- New observations and relevant revision history supply evidence for changes and context for earlier decisions.

- The questions the model must answer guide queries and the distinctions each representation must preserve.

---

## Abduction

_Devise an explanation for observations._

- Propose revisions to the entities, relationships, and constraints that explain the observations.

- Propose or revise the mapping of identities and notation into a stricter representation.

  - Keep unknowns explicit and identify prose whose meaning requires interpretation before translation.

---

## Deduction

_Derive consequences of the explanation._

- Derive representative queries, expected answers, and checks that would expose missing or contradictory claims.

- Specify which facts and relationships must agree across representations, including changes from the previous revision.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Update the shared model interactively. Refresh its stricter representation before relying on answers affected by the changes.

- Run the queries and checks, then compare their results with the expected answers and mapped source facts.

  - Compare meanings rather than formatting, distinguishing derived conclusions from stated facts.

  - For Markdown tables, use the JSON extraction in @../mat/SKILL.md.

- Reconcile discrepancies and incorporate findings into the shared model.

  - Preserve unmapped content and unresolved conflicts.

- Review the diff for lost requirements or unintended changes in meaning.

---

## Representations

- Use @../dot/SKILL.md to visualize entities and relationships.

  - Derive views from the model's queries, keeping presentation separate from domain facts and inference rules.

- See `./references/prolog.md` for one example representation of facts, inference rules, and queries.
