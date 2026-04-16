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
  - `...` for noop bodies, not `pass`.
  - `suppress()` over bare `try/except`.
  - `with nullcontext(): ...` to group related statements.
  - No `if __name__ == "__main__":` guard — scripts execute at module scope.

- Prefix non-exported module-level names with `_` — constants, functions, classes.

- `@dataclass(frozen=True)` for data types.

- `getLogger()` over `print`. Call `getLogger()` at the site of logging — never store or pass a logger. `"%s"` as the format string, f-string as the argument: `getLogger().info("%s", f"{count} entries")`.

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
