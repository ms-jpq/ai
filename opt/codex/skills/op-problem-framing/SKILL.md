---
name: op-problem-framing
description: Classify a system's obstructing problems and prioritize their concerns.
---

# Problem Framing

- Seek prior art in the domain and adjacent disciplines.

  - Record relevant differences from the current problem.

---

## Artifact (Output)

_State the intended properties declaratively._

- **Problems:** A hierarchy explaining what obstructs the system's purpose.

- **Concerns:** What matters in addressing each problem, ranked by salience.

---

## Observation (Input)

_State the input categories and their roles._

- **Purpose and boundary:** What the system should achieve and what it includes.

- **Observations:** Failures, delays, and other obstacles to that purpose.

- **Current framing:** Existing problems, concerns, and priorities to reassess.

---

## Abduction

_Devise an explanation for observations._

- Propose a problem hierarchy that explains what obstructs the system's purpose.

  - Keep candidate problems distinct until their independent, coupled, or nested relationships are established.

  - Evaluate prior art as a candidate frame.

- Enumerate each problem's concerns and justify their priorities.

---

## Deduction

_Derive consequences of the explanation._

- Derive observations that distinguish competing problem hierarchies and priorities.

- Predict how resolving each problem would advance the system purpose.

- Predict which salient concerns require a structural response, such as new components or changed relationships.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Test the hierarchy and priorities against observed obstacles and alternative explanations.

- Retain concerns that explain obstacles or affect the response to them.
