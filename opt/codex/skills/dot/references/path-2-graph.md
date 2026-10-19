# Path to Graph

- One slash-separated chain per line: `a/b/x`.

- A leading `./` or `/` is ignored.

  ```tree
  a/x
  ./b/x
  /x
  ```

- Each basename is a node ID. Repeated names identify the same node: `a/x` and `b/x` share x.

- Choose an adjacency direction:

  - _`outgoing`_: `a/b/x` represents a → b → x.

  - _`incoming`_: `a/b/x` represents a ← b ← x.

---

## File System

- Use symlinks to represent shared nodes: a/x and b/x can both point to the same x.

  ```bash
  mkdir --parents -- a b x
  ln --symbolic --no-target-directory --no-dereference --force --relative -- x a/x
  ln --symbolic --no-target-directory --no-dereference --force --relative -- x b/x
  ```

- List paths without following symlinks, so cycles do not cause recursive traversal.

  ```bash
  env -C '<ROOT>' -- find . -mindepth 1 > '<chains>.txt'
  tree --fromfile --noreport -- . < '<chains>.txt'
  ```

---

## Conversion

```bash
../scripts/paths-to-dot.py outgoing < '<chains>.txt' > '<graph>.dot'

../scripts/paths-to-dot.py incoming < '<chains>.txt' > '<graph>.dot'
```
