# Python Guidelines

- Use `from module import name` for all imports — never bare `import module`.

- Prefix all non-exported module-level names with `_` — constants, functions, and classes alike.

- Type-annotate all function and method signatures.

- Use the most generic type. For example: `Sequence[T]` over `list[T]`, `Mapping[K, V]` over `dict[K, V]`.

- Use `pathlib.Path` over `os.path` for path manipulation where possible.

- Type iterables in input positions as `Iterable[T]` / `AsyncIterable[T]`, and in output positions as `Iterator[T]` / `AsyncIterator[T]`.

- Prefer literal syntax and comprehensions over constructor calls: `[]` not `list()`, `{}` not `dict()`, `{*x}` not `set(x)`, `{1, 2}` not `set([1, 2])`, `[v for v in x]` not `list(x)`.

- No `if __name__ == "__main__":` guard — scripts execute at module scope.

- Use `...` (ellipsis) for noop bodies, not `pass`.

- Use `suppress()` over `try/except` for simple exception suppression.

- Use `getLogger(__name__)` for output instead of `print`. Use `%s`-style placeholders, not f-strings: `log.info("%s entries", count)`.

- Use `with nullcontext(): ...` to group related statements together.

- Prefer frozen dataclasses (`@dataclass(frozen=True)`) for data types.

- Use `from argparse import ArgumentParser, Namespace`. Parse into a `Namespace`, then destructure into typed locals.
  - Always use keyword arguments in `add_argument` — spell out `action=`, `type=`, `default=`, `nargs=`, `required=`.
  - Use `add_mutually_exclusive_group()` for conflicting flags.
  - Use `add_subparsers(dest=..., required=True)` for multi-command CLIs, dispatch with `match`/`case`.

```python
def _parse_args() -> Namespace:
    parser = ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("paths", nargs="+")
    return parser.parse_args()
```