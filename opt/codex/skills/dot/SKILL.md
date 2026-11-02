---
name: dot
description: Translate an existing graph from filesystems, tables, or other representations into Graphviz DOT.
---

# Dot

## Artifact (Output)

_State the intended properties declaratively._

- The DOT preserves the source graph's identities, relationship directions, and retained attributes under an explicit mapping.

- Conversion is reproducible when the source changes, and scoped omissions or unresolved mappings are explicit.

- Any rendered view preserves topology while making the intended relationships readable.

---

## Observation (Input)

_State the input categories and their roles._

- The source representation supplies the graph to translate.

- Source conventions establish entity identity, relationship direction, and attribute meaning.

---

## Abduction

_Devise an explanation for observations._

- Propose a source-to-DOT mapping that preserves identity and relationship meaning.

  - Distinguish missing information from absent relationships.

  - Resolve ambiguous source conventions before encoding them. A directory parent, a symlink target, and a dependency are different relationships.

- When a visualization is wanted, choose layout and styling separately from the graph's topology.

---

## Deduction

_Derive consequences of the explanation._

- Derive the expected node and edge sets from the mapping, including isolated nodes, parallel edges, and cycles where present.

- Identify what the conversion could merge, reverse, or omit and how to check it against the source.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Generate DOT and check that Graphviz parses it.

- Compare node identities, edge endpoints, directions, and retained attributes with the source. Counts alone do not establish fidelity.

- If rendering, inspect readability and adjust presentation while preserving topology.

- Deliver the DOT and conversion command, with any unresolved mappings or omissions.

---

## References

- `./references/path-2-graph.md`.

- `./references/prolog-2-dot.md`.

- `./references/large-dag-visualisation.md`.
