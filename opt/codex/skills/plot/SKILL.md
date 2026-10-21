---
name: plot
description: Visualise quantitative data or functions using reproducible gnuplot scripts.
---

# Plot

## Artifact (Output)

- A gnuplot script, its source data or data-generation command, and the rendered plot.

---

## Observation (Input)

- Identify the question the plot should answer, the source values, units, and missing observations.

- Identify the destination and required output format or interactive terminal.

---

## Abduction

_Devise an explanation for observations._

- Choose axes, scales, series, and plot styles that expose the relevant comparison or relationship.

  - Keep transformations, aggregation, and uncertainty explicit.

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

- Revise the presentation where the intended comparison is unclear.

- Deliver the script, data, plot, and reproduction command.
