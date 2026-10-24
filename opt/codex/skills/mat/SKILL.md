---
name: mat
description: Represent a system's state space densely using Markdown tables.
---

# Mat

- Use @../fold/SKILL.md for subsequent document edits: first incorporate changes into the existing matrix, revising its axes or notation as needed.

  - Keep supporting explanations and anything the matrix cannot express clearly outside the cells.

---

## Artifact (Output)

- A dense, parsable Markdown representation of the state space defined by the chosen dimensions and constraints.

- A legend defining the notation used inside cells, with detailed explanations outside the tables.

---

## Observation (Input)

- Read the system, its existing representations, and the question the tables should answer.

- Identify relevant dimensions, their possible values, constraints, and unknowns.

---

## Abduction

_Devise an explanation for observations._

- Propose table axes and related views that represent the chosen state space compactly.

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

- Populate the tables using the notation consistently, keeping cells succinct and detailed explanations outside them.

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
