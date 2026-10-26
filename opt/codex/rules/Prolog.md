---
paths:
  - "*.pro"
  - "*.prolog"
---

# Prolog

## Defaults

- Use `.pro` for standalone SWI-Prolog scripts.

- Typical script prelude:

  ```prolog
  #!/usr/bin/env -S -- swipl

  :- initialization(main, main).

  main(_Argv) :-
      true.
  ```

- Accept command-line arguments through `main/1`.

---

## Effects

- Use `setup_call_cleanup/3` to acquire streams, use them, and close them even when the operation fails or throws.

---

## Process Control

- Use `process_create/3` with an argument list for subprocesses.

  - When managing a process explicitly, collect its exit status with `process_wait/2` and check it.
