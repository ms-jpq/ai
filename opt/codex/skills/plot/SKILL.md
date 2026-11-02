---
name: plot
description: Visualize quantitative data or functions using reproducible gnuplot scripts.
---

# Plot

## Artifact (Output)

_State the intended properties declaratively._

- The rendered plot makes the intended comparison or relationship readable without obscuring relevant source values, ranges, or trends.

- Labels identify quantities, units, and series.

  - Scales, transformations, aggregation, and uncertainty are explicit.

- The plot is reproducible in the required format from the supplied gnuplot script, data or data-generation command, and invocation.

---

## Observation (Input)

_State the input categories and their roles._

- The question to answer defines the comparison or relationship the plot should reveal.

- Source data or functions supply the values to plot, with units and missing observations informing their interpretation.

- The destination, format, and interactive-terminal requirements constrain rendering.

---

## Abduction

_Devise an explanation for observations._

- Choose axes, scales, series, and plot styles that expose the relevant comparison or relationship.

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
