---
name: interactive-modeling
description: Progressively build a model through conversation, maintaining the model and its executable representation under source control.
---

# Interactive Modelling

- Develop the model together in chat or a shared document.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Revised model:** Entities, relationships, and constraints developed through conversation, with unresolved questions explicit.

- **Executable representation:** A form of the model supporting reproducible queries and checks.

- Both are maintained under source control, with their mappings and checks.

---

## Observation (Input)

_State the input categories and their roles._

- **Model:** The current model and any executable representation, mappings, and revision history. The model may initially be absent.

- **Interactions:** Questions, explanations, examples, observations, corrections, and decisions exchanged while developing the model.

---

## Abduction

_Devise an explanation for observations._

- Propose revisions to the entities, relationships, and constraints that explain the observations.

- Propose or revise the mapping of identities and notation into the executable representation.

  - Keep unknowns explicit and identify prose whose meaning requires interpretation before translation.

---

## Deduction

_Derive consequences of the explanation._

- Derive representative queries, expected answers, and checks that would expose missing or contradictory claims.

- Specify which facts and relationships must agree across representations, including changes from the previous revision.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Refresh the model's executable representation before relying on answers affected by changes.

- Run the queries and checks, then compare their results with the expected answers and mapped source facts.

  - Compare meanings, distinguishing derived conclusions from stated facts.

- Reconcile discrepancies and incorporate findings into the shared model.

  - Preserve unmapped content and unresolved conflicts.

---

## Representations

- See `./references/prolog.md` for an example representation of facts, inference rules, and queries.

---

- Use @../converge/SKILL.md when ambiguity, surprising results, or failed checks expose gaps in the model.

- Use @../fold/SKILL.md to incorporate new observations and decisions into the existing model.

- Use @../reconcile/SKILL.md to reconcile the representations when their claims diverge.

- Use @../mat/SKILL.md when tables clarify the model's dimensions and relationships.

  - Use its JSON extraction to check Markdown tables against the executable representation.

- Use @../dot/SKILL.md to visualize entities and relationships.

  - Derive views from the model's queries, keeping presentation separate from domain facts and inference rules.
