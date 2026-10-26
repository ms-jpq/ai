# Prolog

- Use Prolog for domain facts, relationships, constraints, and inference.

- Keep orchestration and presentation outside the model. Use JSON for interchange with other tools.

- Expose queries and checks through scriptable CLI entrypoints that run and exit without an interactive session.

---

## Gap Exploration

- Use @../../gap-analysis/SKILL.md to identify consequential omissions and express them as queries over the model.

- Enumerate the declared domain systematically rather than checking only selected examples.

  - Look for missing relationships, uncovered cases, contradictory obligations, and unreachable outcomes where applicable.

  - Return the entities and conditions witnessing each gap as JSON for review and reconciliation.

- State the domains and search bounds covered. Claim exhaustive coverage only when enumeration completes over that scope.

- Distinguish missing knowledge from false claims. No findings establish only what the encoded model and completed checks cover.

---

## References

- [SWI-Prolog command-line options](https://www.swi-prolog.org/pldoc/man?section=cmdline).

- [JSON input and output](https://www.swi-prolog.org/pldoc/man?section=json).
