---
paths:
  - "*.lua"
---

# Lua

## State and Scope

- Use closure factories for stateful objects and plain tables for stateless modules.

- Scope related declarations with `do...end` blocks.

- Use an IIFE `(function() ... end)()` for computed constants.

---

## Tables and Iteration

- Use `table.insert` / `table.remove` instead of manual index arithmetic.

- Use `unpack()` for destructuring, including single-element extraction.

- Prefer `pairs` to `ipairs`; use `ipairs` when iteration requires contiguous numeric order and hole termination.

---

## Strings

- Use `[[...]]` raw strings for content containing backslashes or angle brackets.

---

## Neovim Standard Library

- Prefer Lua patterns with `string.gsub` / `string.match`. Use `vim.fn.escape` / `vim.re` when Lua patterns cannot express the operation.

- Use `vim.fs.joinpath` instead of concatenating `/` manually.

- Use `vim.split(s, sep, { plain = true })` for literal splitting.

- Use `vim.iter` for functional iteration over tables and iterators.
