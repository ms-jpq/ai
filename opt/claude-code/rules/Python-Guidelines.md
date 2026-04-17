# Python Guidelines

Typical script prelude:

```python
#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from contextlib import nullcontext
from logging import INFO, basicConfig, captureWarnings

with nullcontext():
    captureWarnings(True)
    basicConfig(format="%(message)s", level=INFO)
```

- `from module import name` for all imports — never bare `import module`.

- Functions with multiple parameters use `*` after the first positional argument — forces keyword passing for the rest.

```python
def fetch(url, *, timeout=30, retries=3): ...
def render(template, *, context, strict=False): ...
```

- Control flow idioms:
  - `match/case` over `isinstance` chains and nested `if/elif` on type or shape.
  - `:=` to collapse assign-then-test into one expression.
  - `suppress()` over bare `try/except`.
  - `...` for noop bodies, not `pass`.
  - No `if __name__ == "__main__":` guard — scripts execute at module scope.
  - `with nullcontext(): ...` to group related statements.
  - Single `with a, b:` over nested `with a: with b:`.

- Prefix non-exported module-level names with `_` — constants, functions, classes.

- `@dataclass(frozen=True)` for data types.

- `@contextmanager` to extract repeated try/except/log, timing, and atomic I/O patterns.

- `TypedDict` for JSON input shapes — model the structure, use typed field access.

- `.get()` over `["key"]` on untrusted data. Reserve bracket access for shapes that are known to the type checker.

- `dict.setdefault()` over check-then-insert.

- Generators over closure/nonlocal for stateful iteration that yields results incrementally.

- `getLogger()` over `print`. Call `getLogger()` at the site of logging — never store or pass a logger. `"%s"` as the format string, f-string as the argument: `getLogger().info("%s", f"{count} entries")`. For errors, log `e` directly: `getLogger().error("%s", e, exc_info=True)`.

- `argparse` for CLIs.
  - Spell out keyword arguments: `action=`, `type=`, `default=`, `nargs=`, `required=`.
  - `add_mutually_exclusive_group()` for conflicting flags.
  - `add_subparsers(dest=..., required=True)` for multi-command CLIs, dispatch with `match`/`case`.

```python
def _parse_args() -> Namespace:
    parser = ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("paths", nargs="+")
    return parser.parse_args()
```
