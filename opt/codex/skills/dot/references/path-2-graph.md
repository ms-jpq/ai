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

- Use relative symlinks to represent shared nodes: a/x and b/x can both point to the same x.

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

### Conversion

```bash
../scripts/path-2-dot.py outgoing < '<chains>.txt' > '<topology>.gv'

../scripts/path-2-dot.py incoming < '<chains>.txt' > '<topology>.gv'
```

---

## Extensions

- Filesystem metadata convention:

  ```text
  <ROOT>/
  ├── .rankdir=
  ├── .splines=
  └── a/
      ├── .label=
      ├── .color=
      ├── x → ../x
      └── .x/
          ├── .label=
          └── .style=
  ```

- `.<attribute>=` stores a DOT attribute's value: `.color=` containing `blue` sets `color=blue`.

  - Ordinary directory names must not contain `=`.

- Files directly under `<ROOT>` set graph attributes, such as `.rankdir=` containing `TB` or `.splines=` containing `ortho`.

- `.x/` holds edge attributes for the relationship to `x`.

- Skip hidden entries and their contents when extracting topology.

### Conversion

```bash
DIRECTION=outgoing
ROOT='<ROOT>'

env -C "$ROOT" -- find . -mindepth 1 '(' -name '.*' -prune ')' -or -print > '<chains>.txt'

../scripts/path-2-dot.py "$DIRECTION" < '<chains>.txt' > '<topology>.gv'
```

```bash
env -C "$ROOT" -- grep --recursive --with-filename --include '.?*=' -e '.' > '<metadata>.txt'

exec {FD}< '<metadata>.txt'
../scripts/fs-annotate.gvpr -a "$DIRECTION /dev/fd/$FD" < '<topology>.gv' > '<annotated>.gv'
exec {FD}<&-
```

- For shared styling, run a gvpr pass before loading metadata so individual attributes can override it.
