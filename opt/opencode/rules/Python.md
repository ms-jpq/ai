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

- When writing and calling functions, use named parameters after the first positional argument.

  ```python
  def fetch(url: str, *, timeout: float = 30.0, retries: int = 3) -> bytes: ...

  fetch(source, timeout=30, retries=3)
  ```

- Use generators to keep incremental iteration state inside the iterator.

  ```python
  def chunks[T](items: Sequence[T], *, size: int) -> Iterator[Sequence[T]]:
      index = 0
      while index < len(items):
          yield items[index : index + size]
          index += size
  ```

---

## Control Flow

- Use `match`/`case` to enumerate the state space.

  ```python
  state: Literal["idle", "running", "done"]
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

- Read typed records through destructuring or typed field access.

  ```python
  payload: object
  match payload:
      case {"name": str(name), "limit": int(limit)}:
          ...
      case _:
          raise TypeError(payload)
  ```

---

## Transforms

- Chain collection transforms instead of mutating an accumulator.

- Use comprehensions, generator expressions, `map()`, `filter()`, and `dict`/`list` constructors for local transforms.

  ```python
  pairs: Iterable[tuple[str, int | None]]
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
  def managed(resource: IO[str]) -> Iterator[IO[str]]:
      try:
          yield resource
      finally:
          resource.close()
  ```

- Use `getLogger()` instead of `print`; call it inline at each site.

  ```python
  count: int
  getLogger().info("%d entries", count)

  error: Exception
  getLogger().error("%s", error, exc_info=True)
  ```
