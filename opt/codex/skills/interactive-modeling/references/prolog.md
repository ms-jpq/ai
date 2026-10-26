# Prolog

- Map stable entity IDs to atoms and named relationships to predicates with documented argument order.

- Separate translated facts from hand-maintained inference rules and validation queries so regeneration preserves the latter.

- Translate only explicitly defined notation mechanically. Review interpretations of free prose before treating them as model facts.

---

## Correspondence

- For a Markdown relation table with columns `stage`, `relation`, and `condition`:

  | stage   | relation | condition          |
  | ------- | -------- | ------------------ |
  | cutover | requires | copy_verified      |
  | cutover | ensures  | destination_active |

  ```prolog
  requires(cutover, copy_verified).
  ensures(cutover, destination_active).
  ```

- Decode the table export into relation tuples and compare them with the model's direct facts, preserving IDs and argument order.

  - Table extraction returns cell strings; the declared mapping supplies their meaning.

- Keep assertions about requirements separate from evidence that they hold. A failed query does not by itself establish the opposite claim about the real system.

---

## Interaction

- Load the model with `swipl '<model>.pl'`, query `requires(cutover, What).`, and reload saved changes with `make.`.

- Save accepted model changes in files; an interactive session alone does not preserve revision history.

- See: [SWI-Prolog interaction](https://www.swi-prolog.org/pldoc/man?section=quickstart).
