---
name: cost
description: Maintain a calculable cost model to choose the lowest-cost way to meet requirements.
---

# Cost

## Artifact (Output)

_State the intended properties declaratively._

- **Cost model:** Executable formulas with editable inputs, units, assumptions, and a comparison rule.

- **Decision:** The lowest-cost feasible alternative, or the unresolved trade-off preventing a choice.

---

## Observation (Input)

_State the input categories and their roles._

- **Requirements:** The outcome, constraints, and quality threshold each alternative must satisfy.

- **Alternatives:** Available ways of achieving the outcome, including the current approach.

- **Cost inputs:** Measured values, estimated ranges, and unknowns for a specified workload and time horizon.

- **Cost model:** Existing calculations and decision rules, if defined.

---

## Abduction

_Devise an explanation for observations._

- Propose formulas for each alternative's costs over the same workload and time horizon.

  - Include human attention, implementation, operation, maintenance, and rework as applicable.

  - Separate one-time and recurring costs, accounting for shared costs once.

- Establish a common cost currency and its conversion rules.

  - For example, wall-clock time measures elapsed time, including waits and overlapping work.

  - Keep costs that cannot be converted separate.

---

## Deduction

_Derive consequences of the explanation._

- Calculate costs for alternatives that meet the requirements.

  - Vary uncertain inputs to find where the preferred alternative changes.

  - Identify which missing measurements could change the decision.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Run the calculations against observed cases and correct discrepancies.

- Select an alternative using the comparison rule, or state what prevents a choice.

- Reuse and update the model as decisions and inputs change.

---

- Use @../mat/SKILL.md to compare alternatives and cost components in tables.

- Use @../sop/SKILL.md when costs depend on the stages and frequency of a recurring procedure.
