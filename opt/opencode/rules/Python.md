---
paths:
  - "*.py"
---

# Python

## Defaults

- Typical script prelude:

  ```python
  #!/usr/bin/env -S -- PYTHONSAFEPATH= python3

  from contextlib import nullcontext
  from logging import INFO, basicConfig, captureWarnings

  with nullcontext():
      captureWarnings(True)
      basicConfig(format="%(message)s", level=INFO)
  ```

- Import names directly with `from module import name`.

- Prefix non-exported module-level constants, functions, and classes with `_`.

---

## Functions

- After the first positional parameter, use `*` to make remaining parameters keyword-only.

  ```python
  def fetch(url, *, timeout=30, retries=3): ...
  def render(template, *, context, strict=False): ...
  ```

- Use generators instead of closures with `nonlocal` for incremental stateful iteration.

---

## Control Flow

- Use `match`/`case` instead of `isinstance` chains or nested `if`/`elif` branches on type or shape.

- Use `:=` when a value is both assigned and tested.

- Use `suppress()` when intentionally ignoring a specific exception; never use bare `except`.

- Use `...` for intentional no-op bodies.

- Execute scripts at module scope.

- Use `with nullcontext(): ...` to give related statements a visual scope.

- Combine context managers in one `with a, b:` statement.

---

## Data Modeling

- Use `@dataclass(frozen=True)` for immutable data types.

- Model JSON object shapes with `TypedDict` and typed field access.

- Use `.get()` for optional keys in untrusted mappings. Use bracket access for required keys represented in the type.

- Use `dict.setdefault()` instead of check-then-insert.

---

## Effects

- Use `@contextmanager` to extract repeated setup, teardown, timing, logging, and atomic I/O patterns.

- Use `getLogger()` instead of `print`; call it inline at each site. Pass format arguments separately: `getLogger().info("%d entries", count)`. Inside exception handlers, include the traceback: `getLogger().error("%s", error, exc_info=True)`.

---

## Command-Line Interfaces

- Use `argparse` for CLIs.

  - Spell out keyword arguments: `action=`, `type=`, `default=`, `nargs=`, `required=`.

  - Use `add_mutually_exclusive_group()` for conflicting flags.

  - Use `add_subparsers(dest=..., required=True)` for multi-command CLIs; dispatch with `match`/`case`.

  ```python
  def _parse_args() -> Namespace:
      parser = ArgumentParser()
      parser.add_argument("--output", required=True)
      parser.add_argument("--dry-run", action="store_true")
      parser.add_argument("paths", nargs="+")
      return parser.parse_args()
  ```
