---
paths:
  - "**/*.lua"
---

# Lua

- Closure factories for stateful objects. Plain tables for stateless modules.

- `table.insert` / `table.remove` over manual index arithmetic.

- `unpack()` for destructuring, including single-element extraction.

- `pairs` over `ipairs`.

- `do...end` blocks to scope related declarations together.

- `[[...]]` raw strings for content with backslashes or angle brackets.

- IIFE `(function() ... end)()` for computed constants.

## Neovim stdlib

- Prefer `string.gsub` / `string.match` lua patterns. `vim.fn.escape` / `vim.re` when lua patterns lack the feature.

- `vim.fs.joinpath` over manual `/` concatenation.

- `vim.split(s, sep, { plain = true })` for non-regex splitting.

- `vim.iter` for functional iteration over tables and iterators.
