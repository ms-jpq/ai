---
name: mat
description: Represent a system's state space densely using Markdown tables.
---

- Establish a dense, parsable representation of the full state space defined by the system's chosen dimensions using Markdown tables.

- Define a compact notation using emoji, symbols, and short labels in a legend, then apply it consistently inside cells to represent the combinations of dimension values.

- Combine symbols to express relationships or order. For example, with `🍎 = A`, `🍏 = B`, and `→ = then`, distinguish `🍎 → 🍏` from `🍏 → 🍎`.

- Keep detailed explanations outside the cells.

## Errata

- In interactive documents, avoid inline code, bold, italic, and Markdown links because they interact poorly with Neovim. Use plain text and symbols instead.

## Machine Parsability

```json
{
  "devDependencies": {
    "remark-cli": "*",
    "remark-gfm": "*"
  }
}
```

```bash
remark --no-config --use remark-gfm --tree-out -- '<spec>.md' | jq -e '[recurse(select(.type != "table") | .children[]?) | select(.type == "table")]'
```

- See: [The AST format](https://github.com/syntax-tree/mdast)
