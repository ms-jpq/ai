---
paths:
  - "*.py"
  - "*.pyi"
  - "*.pyw"
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

- When writing functions, require named parameters after the first positional argument.

  ```python
  def fetch(url, *, timeout=30, retries=3): ...
  ```

- When calling functions, pass arguments by name unless the parameter is the primary object being acted on.

  ```python
  fetch(source, timeout=30, retries=3)
  ```

- Use generators instead of closures with `nonlocal` for incremental stateful iteration.

  ```python
  def chunks(items, *, size):
      index = 0
      while index < len(items):
          yield items[index : index + size]
          index += size
  ```

---

## Control Flow

- Use `match`/`case` to enumerate all possible cases.

  ```python
  match state:
      case "idle":
          start()
      case "running":
          poll()
      case "done":
          finish()
      case _:
          assert False
  ```

- Use `:=` when a value is both assigned and tested.

  ```python
  if (match := pattern.search(text)) is None:
      continue
  ```

- Use `suppress()` when intentionally ignoring a specific exception.

  ```python
  with suppress(ValueError):
      return tuple(values)
  return None
  ```

- Use `...` for intentional no-op bodies.

- Use `with nullcontext(): ...` to give related statements a visual scope.

---

## Data Access

- After parsing, reading, decoding, or transforming, bind the expected shape before using it.

  ```python
  match payload:
      case {"name": str(name), "limit": int(limit)}:
          ...
      case _:
          raise TypeError(payload)
  ```

- Read typed records through destructuring or typed field access.

---

## Transforms

- Chain collection transforms instead of mutating an accumulator.

- Use comprehensions, generator expressions, `map()`, `filter()`, and `dict`/`list` constructors for local transforms.

  ```python
  selected = {key: value for key, value in pairs if value is not None}
  ```

- Use `dict.setdefault()` instead of check-then-insert.

---

## Data Modeling

- Use `@dataclass(slots=True, frozen=True)` for immutable data types.

- Model JSON object shapes with `TypedDict` and typed field access.

  ```python
  class CommandRecord(TypedDict):
      name: str
      options: Mapping[str, _OptionSpec]
  ```

---

## Effects

- Use `@contextmanager` to extract repeated setup, teardown, timing, logging.

  ```python
  @contextmanager
  def managed(resource):
      try:
          yield resource
      finally:
          resource.close()
  ```

- Use `getLogger()` instead of `print`; call it inline at each site.

  ```python
  getLogger().info("%d entries", count)

  getLogger().error("%s", error, exc_info=True)
  ```

---

## Command-Line Interfaces

```python
def _parse_args() -> Namespace:
    parser = ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("paths", nargs="+")
    return parser.parse_args()
```
