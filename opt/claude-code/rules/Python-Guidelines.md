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

- Type-annotate all signatures. Use the most generic type: `Sequence[T]` over `list[T]`, `Mapping[K, V]` over `dict[K, V]`, `Iterable[T]`/`AsyncIterable[T]` for inputs, `Iterator[T]`/`AsyncIterator[T]` for outputs.

- Prefix non-exported module-level names with `_` — constants, functions, classes.

- `pathlib.Path` over `os.path`. Library constants over string literals: `linesep` not `"\n"`, `sep` not `"/"`, `executable` not `"python3"`.

- Literals and comprehensions over constructors: `[]` not `list()`, `{}` not `dict()`, `{*x}` not `set(x)`.

- Prefer iterator-based solutions: `zip`, `enumerate`, `chain`, `product`, `starmap`, etc. over manual loops and index arithmetic.

- `getLogger()` over `print`. Always call `getLogger()` at the site of logging — never store or pass a logger. Always `"%s"` as the format string, f-string as the argument: `getLogger().info("%s", f"{count} entries")`.

- `...` for noop bodies, not `pass`. `suppress()` over bare `try/except`. `with nullcontext(): ...` to group related statements. No `if __name__ == "__main__":` guard — scripts execute at module scope.

- Prefer frozen dataclasses (`@dataclass(frozen=True)`) for data types.

- `from argparse import ArgumentParser, Namespace`. Parse into a `Namespace`, destructure into typed locals.
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
