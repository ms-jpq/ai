# Python Guidelines

- `from module import name` for all imports — never bare `import module`.

- Type-annotate all signatures. Use the most generic type: `Sequence[T]` over `list[T]`, `Mapping[K, V]` over `dict[K, V]`, `Iterable[T]`/`AsyncIterable[T]` for inputs, `Iterator[T]`/`AsyncIterator[T]` for outputs.

- Prefix non-exported module-level names with `_` — constants, functions, classes.

- `pathlib.Path` over `os.path`. Library constants over string literals: `linesep` not `"\n"`, `sep` not `"/"`, `executable` not `"python3"`.

- Literals and comprehensions over constructors: `[]` not `list()`, `{}` not `dict()`, `{*x}` not `set(x)`.

- `getLogger(__name__)` over `print`. `%s`-style placeholders, not f-strings: `log.info("%s entries", count)`.

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
