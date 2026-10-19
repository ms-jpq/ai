# Large DAG Visualisation

- Trace dependencies among hundreds of nodes in a webpage without reading the whole graph at once.

- Pipeline: `graph in DOT → enrich via graph-processing → viewer`.

  - Prefer existing Graphviz tools before building custom ones.

    - Discover available tools:

      ```bash
      dpkg-query --listfiles graphviz | grep -E -e '/bin/'
      ```

    - Use gvpr for custom filtering and annotation.

      - See `../scripts/*` for local conversion and annotation scripts.

---

## Layout

- Prefer top-to-bottom dependency flow for vertical scrolling.

- Define arrow direction so prerequisites and dependants are unambiguous.

- Keep labels short and expose details on demand.

- Conduct parallel trials of layout settings and graph-processing passes against the same graph, task, and constraints.

  - Consider the concerns below, then retain the measures that help distinguish useful views.

  - Reject candidates that lose required nodes, relationships, or arrow meaning.

- Present the tested candidates' **Pareto frontier** as viewer tabs, labelled with settings, scores, and tradeoffs.

  - Keep candidates for which no other is at least as good on every selected objective and better on at least one.

  - This frontier covers the trials, not every possible layout.

  - Keep scores separate. Metrics approximate readability, and the reader makes the final choice.

### Readability Considerations

- Notation: 📉 minimise, 📈 maximise, ? unmeasured, N/A inapplicable.

| Concern          | Aim | Example assessment                                          |
| ---------------- | --- | ----------------------------------------------------------- |
| Crossings        | 📉  | `grep -E -e '^mincross .* crossings' < '<layout>.log'`      |
| Edge conflicts   | 📉  | `grep -F -e 'The edge conflict graph has' < '<colour>.log'` |
| Edge distinction | 📈  | `grep -F -e 'final color_diff=' < '<colour>.log'`           |
| Command runtime  | 📉  | `/usr/bin/time -f '%e' -o '<timing>.log' <command>`         |
| ...              | ... | ...                                                         |

- These are examples, not a requirement to implement every measurement.

  - Record unmeasured concerns as ?.

  - Prune ranking objectives when trials show they are redundant, unreliable, or do not help distinguish useful views.

  - Retain the queries and evidence so those decisions can be revisited on different graphs.

- Inspect unmeasured concerns visually. Use only comparable measured scores for dominance comparisons.

---

## Navigation

- Support background dragging to pan, zoom around the pointer, fit-to-view, and reset.

  - Preserve ordinary wheel scrolling. Use a modifier or explicit controls for zoom.

- Preserve the viewport when changing scope where possible.

- Find a node by identifier or label and bring it into view.

- Support multi-select, including adding and removing individual nodes.

- Link node labels to their source URIs.

  - Keep opening links distinct from selecting nodes.

---

## Relationships and Scope

- Highlight a selected node's ancestors, descendants, or both, including their connecting edges.

  - Keep node positions fixed during selection and highlighting.

  - Dim unrelated elements.

  - Hover previews a selection, click pins it, and Escape clears it.

  - Distinguish the selected node, prerequisites, and dependants with consistent styling.

- Isolate a neighbourhood, dependency path, or group when highlighting leaves too much clutter.

  - Mark connections outside the visible scope with counts or boundary markers.

  - Collapse and expand meaningful groups while retaining their external connections.

---

## Checks

- Check readability and responsiveness against the requirements above using 250 nodes with long chains, broad fan-out, and shared dependencies.

  - Check that highlighting distinguishes edges at crossings and along shared tracks.

---

## Diagnostic Examples

- Capture diagnostics once per candidate using its trial settings, then query the saved logs:

  ```bash
  dot -v < '<graph>.gv' > /dev/null 2> '<layout>.log'

  edgepaint -v -random_seed=42 -color_scheme=dark28 -angle=89 '<positioned>.gv' > /dev/null 2> '<colour>.log'
  ```

- The positioned graph must contain the candidate's node positions and routed edge paths.

- GNU `time` records elapsed seconds with `%e`:

  ```bash
  /usr/bin/time -f '%e' -o '<timing>.log' dot < '<graph>.gv' > /dev/null
  ```

- Use the same measurement definitions, Graphviz version, palette, and conflict threshold across trials.
