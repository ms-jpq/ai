---
name: mat
description: Represent a system's state space densely using Markdown tables.
---

# Mat

- Use @../fold/SKILL.md for subsequent document edits: first incorporate changes into the existing matrix, revising its axes or notation as needed.

  - Keep supporting explanations and anything the matrix cannot express clearly outside the cells.

---

## Artifact (Output)

_State the intended properties declaratively._

- Parsable Markdown tables densely represent the combinations defined by the chosen dimensions and constraints, with gaps visible.

- Cell meanings are recoverable from a consistent legend, preserving relevant distinctions, relationships, and order.

- Cells remain succinct, with detailed explanations outside the tables. Machine extraction preserves their notation when required.

---

## Observation (Input)

_State the input categories and their roles._

- The system and its existing representations supply known values, relationships, constraints, and unknowns.

- The question the tables should answer determines which dimensions and combinations matter.

---

## Abduction

_Devise an explanation for observations._

- Propose dimensions, their value domains, table axes, and related views that represent the relevant state space compactly.

  - Define the notation using emoji, symbols, and short labels in a legend.

    - Combine symbols to express relationships or order. i.e. with `🍎 = A`, `🍏 = B`, and `→ = then`, distinguish `🍎 → 🍏` from `🍏 → 🍎`.

    - Give unknown, impossible, and inapplicable combinations distinct representations where those distinctions matter.

---

## Deduction

_Derive consequences of the explanation._

- Derive which combinations the tables must cover from the dimension values and constraints.

- Predict how representative cases, including ordering and exceptions, will be encoded and recovered from the cells.

- Identify checks for missing combinations, inconsistent repeated claims, and ambiguous notation.

---

## Induction

_Test those consequences and provisionally retain or revise the explanation._

- Populate the tables using the notation consistently.

- Compare coverage with the expected combinations and trace cell meanings back to the source.

- Revise axes or notation when the representation loses distinctions or obscures gaps.

- When machine parsing is required, extract the tables using the workflow below and verify that the decoded cells preserve the intended notation.

---

## Errata

- In interactive documents, avoid inline code, bold, italic, and Markdown links because they interact poorly with Neovim. Use plain text and symbols instead.

---

## Machine Parsability

- Example uses of the extracted tables include:

  - Linting required columns, duplicate identifiers, and undefined symbols.

  - Checking coverage against declared dimension values and constraints.

  - Generating test cases when notation is bound to executable behaviour.

```json
{
  "devDependencies": {
    "@types/mdast": "*",
    "@types/node": "*",
    "mdast-util-to-string": "*",
    "remark-cli": "*",
    "remark-gfm": "*"
  }
}
```

```bash
remark --no-config --use remark-gfm --tree-out < '<spec>.md' > ast.json

./scripts/mdast-2-rows-and-cols.ts < ast.json > tables.json
```
