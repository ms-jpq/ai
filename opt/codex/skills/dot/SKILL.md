---
name: dot
description: Convert a problem into a base graph in DOT notation, then progressively process it through reproducible passes.
---

# Dot

## Artifact (Output)

_State the intended properties declaratively._

- **Conversion:** A reproducible mapping from the problem to nodes, edges, and attributes.

- **Base graph:** The problem represented in DOT notation, before processing passes.

- **Pipeline:** Reproducible passes that progressively process the base graph.

---

## Observation (Input)

_State the input categories and their roles._

- **Problem:** The entities and relationships to represent, as described in existing graphs, filesystems, tables, or other sources.

- **Conventions:** Rules for node identity, relationship direction, and attribute meaning.

---

## Abduction

_Devise an explanation for observations._

- Propose how the problem maps to nodes, edges, and attributes while preserving identity and relationship meaning.

  - Distinguish missing information from absent relationships.

  - Resolve ambiguous source conventions before encoding them. A directory parent, a symlink target, and a dependency are different relationships.

- When a visualization is wanted, choose layout and styling separately from the graph's topology.

- Compose processing passes over the base graph, including filters and annotations.

---

## Deduction

_Derive consequences of the explanation._

- Derive the expected node and edge sets from the mapping, including isolated nodes, parallel edges, and cycles where present.

- Identify what the conversion could merge, reverse, or omit and how to check it against the source.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Generate DOT and check that Graphviz parses it.

- Compare node identities, edge endpoints, directions, and retained attributes with the source.

- If rendering, inspect readability and adjust presentation while preserving topology.

- Record unresolved mappings and omissions.

---

## References

- `./references/path-2-graph.md`.

- `./references/prolog-2-dot.md`.

- `./references/large-dag-visualisation.md`.
