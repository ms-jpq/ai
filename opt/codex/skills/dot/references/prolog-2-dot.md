# Prolog to DOT

- Query Prolog for the existing graph's nodes, edges, and attributes, then emit DOT from those results.

  - Declare nodes separately so isolated entities remain visible.

  - Preserve stable node IDs, edge direction, and relationship labels.

  - Quote and escape DOT strings explicitly.

- Keep DOT generation separate from the predicates supplying the graph.

---

## Command Line

- Make the exporter an executable Prolog script that accepts the source file through `main/1` and writes DOT to stdout.

  ```bash
  ./write-dot.pro '<source>.pro' > '<graph>.gv'

  dot -Tcanon < '<graph>.gv' > /dev/null
  ```

---

## References

- [SWI-Prolog command-line options](https://www.swi-prolog.org/pldoc/man?section=cmdline).
