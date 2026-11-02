---
name: plot
description: Visualize quantitative data or functions using reproducible gnuplot scripts.
---

# Plot

## Artifact (Output)

_State the intended properties declaratively._

- **Plot:** A readable visualization of the intended comparison or relationship.

- **Reproduction:** The gnuplot script, data, and command needed to regenerate the plot.

---

## Observation (Input)

_State the input categories and their roles._

- **Question:** The comparison or relationship to reveal.

- **Data:** Values or functions to plot, with units and missing observations.

- **Destination:** The required format and display environment.

---

## Abduction

_Devise an explanation for observations._

- Choose axes, scales, series, and plot styles that expose the relevant comparison or relationship.

  - Make transformations, aggregation, and uncertainty explicit.

---

## Deduction

_Derive consequences of the explanation._

- Identify source values, ranges, and trends that should remain recoverable from the plot.

- Check whether clipping, missing values, or the chosen scale could change the apparent conclusion.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Write and run the gnuplot script with an explicit terminal and output destination.

- Inspect the rendering against the source, including labels, units, legends, and obscured data.
