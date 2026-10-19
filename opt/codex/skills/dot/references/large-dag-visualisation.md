# Large DAG Visualisation

- Trace dependencies among hundreds of nodes in a webpage without reading the whole graph at once.

- Pipeline: `DOT graph → enrich with graph-processing tools → viewer`.

  - Prefer existing Graphviz tools before building custom ones.

    - Discover available tools:

      ```bash
      dpkg-query --listfiles graphviz | grep -E -e '/bin/'
      ```

    - Use gvpr for custom filtering and annotation. See `../scripts/*` for local scripts.

---

## Layout

- Prefer top-to-bottom dependency flow for vertical scrolling.

- Define arrow direction so prerequisites and dependants are unambiguous.

- Keep labels short and expose details on demand.

- Run parallel trials of layout settings and graph-processing passes using the same graph, task, and constraints.

  - Choose useful measures from the concerns below.

  - Reject candidates that lose required nodes, relationships, or arrow meaning.

- Present the tested candidates' **Pareto frontier** as viewer tabs.

  - Keep a candidate unless another tested candidate is at least as good on every selected objective and better on at least one.

  - Label tabs with settings, scores, and tradeoffs.

  - Keep scores separate so the reader can choose among tradeoffs.

### Assessment Metrics

- Notation: 📉 minimise, 📈 maximise, ? unmeasured, N/A inapplicable.

| Concern          | Aim | Example assessment                                          |
| ---------------- | --- | ----------------------------------------------------------- |
| Crossings        | 📉  | `grep -E -e '^mincross .* crossings' < '<layout>.log'`      |
| Edge conflicts   | 📉  | `grep -F -e 'The edge conflict graph has' < '<colour>.log'` |
| Edge distinction | 📈  | `grep -F -e 'final color_diff=' < '<colour>.log'`           |
| Command runtime  | 📉  | `/usr/bin/time -f '%e' -o '<timing>.log' <command>`         |
| ...              | ... | ...                                                         |

- Start with these examples, and expand.

  - Record unmeasured concerns as ?.

- Prune objectives that trials show are redundant, unreliable, or unhelpful.

  - Retain queries and evidence to reassess those choices on other graphs.

- Compare dominance using comparable measured scores.

  - Inspect readability visually, including concerns the scores do not capture.

---

## Navigation

- Support background dragging to pan, zoom around the pointer, fit-to-view, and reset.

  - Preserve ordinary wheel scrolling.

  - Use a modifier or explicit controls for zoom.

- Preserve the viewport when changing scope where possible.

- Find a node by identifier or label and bring it into view.

- Let users add and remove individual nodes from a multi-selection.

- Link node labels to their source URIs.

  - Keep opening links distinct from selecting nodes.

---

## Relationships and Scope

- Highlight selected nodes' ancestors, descendants, or both, including their connecting edges.

  - Keep node positions fixed during selection and highlighting.

  - Dim unrelated elements.

  - Hover previews a selection, click pins it, and Escape clears it.

  - Distinguish selected nodes, prerequisites, and dependants with consistent styling.

- Isolate a neighbourhood, dependency path, or group when highlighting leaves too much clutter.

  - Mark connections outside the visible scope with counts or boundary markers.

  - Collapse and expand meaningful groups while retaining their external connections.

---

## Checks

- Check readability and responsiveness using 250 nodes with long chains, broad fan-out, and shared dependencies.

  - Check that highlighting distinguishes edges at crossings and along shared tracks.

---

## Diagnostic Examples

- Capture diagnostics once per candidate using its trial settings, then query the saved logs:

  ```bash
  dot -v < '<graph>.gv' > /dev/null 2> '<layout>.log'

  edgepaint -v -random_seed=42 -color_scheme=dark28 -angle=89 '<positioned>.gv' > /dev/null 2> '<colour>.log'
  ```
