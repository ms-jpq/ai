---
name: dot
description: Translate an existing graph from filesystems, tables, or other representations into Graphviz DOT.
---

# Dot

## Artifact (Output)

- DOT representing the source graph, with a reproducible conversion when the source changes.

- An explicit mapping from source entities and relationships to nodes and edges, including any scoped omissions.

---

## Observation (Input)

- Locate the existing graph, whether represented by filesystem entries, table rows, records, references, or another structure.

- Identify its entities, relationships, direction, and attributes. Distinguish missing information from absent relationships.

---

## Abduction

_Devise an explanation for observations._

- Propose a source-to-DOT mapping that preserves identity and relationship meaning.

- Resolve ambiguous source conventions before encoding them. A directory parent, a symlink target, and a dependency are different relationships.

- When a visualisation is wanted, choose layout and styling separately from the graph's topology.

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

- If rendering, inspect readability and adjust presentation without silently changing topology.

- Deliver the DOT and conversion command, with any unresolved mappings or omissions.

---

## References

- `./references/path-2-graph.md`.

- `./references/large-dag-visualisation.md`.
