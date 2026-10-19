# Large DAG Visualisation

- Trace dependencies among hundreds of nodes in a webpage without reading the whole graph at once.

- Pipeline: `graph in DOT → enrich via graph-processing → viewer`.

  - Prefer existing Graphviz tools before building custom ones.

    - eg. Discover available tools:

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

- Keep node positions fixed during selection and highlighting.

- Preserve the viewport when changing scope where possible.

---

## Navigation

- Support background dragging to pan, zoom around the pointer, fit-to-view, and reset.

  - Preserve ordinary wheel scrolling. Use a modifier or explicit controls for zoom.

- Find a node by identifier or label and bring it into view.

- Link node labels to their source URIs.

  - Keep opening links distinct from selecting nodes.

---

## Relationships and Scope

- Highlight a selected node's ancestors, descendants, or both, including their connecting edges.

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

- Compare layout variants using the **crossing count** reported by `dot -v`.

  ```bash
  ../scripts/dot-diagnostics.sh < '<graph>.gv' | tee -- '<layout>.log' | grep -E -e '^mincross .* crossings'
  ```

  - The count measures rank-order crossings before edge routing, not exact intersections in the rendered graph.

  - Inspect promising variants for overlapping edge tracks, label collisions, and crossing hotspots.
