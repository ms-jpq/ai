# Shell Scripting Guidelines

- Always add a shebang like `#!/usr/bin/env -S -- nodejs`, and mark the file executable with `chmod +x`.

- Always use long form flags when available (`--delimiter` not `-d`) and `--` to terminate option parsing (`cd -- "$DIR"`).

- Always use null bytes as delimiters if possible, i.e. `find ... -print0 | xargs --null ...`

- Avoid writing functions and traps — these make error propagation harder.

- Avoid pipes for passing variables or reading single files.
  - `jq <<< "$JSON"` instead of `echo "$JSON" | jq`
  - `cmd < "$FILE"` or `$(< "$FILE")` instead of `cat "$FILE" | cmd`

- Capture reusable arguments in an array, i.e. `GREP=(grep --recursive ...)`, `${GREP[@]}`.
  - Instead of `\ ` escaping for long / many arguments
  - Instead of functions for code reuse
  - When branches invoke the same command with different arguments
  - Build arrays incrementally with `+=()` based on conditionals

```bash
CURL=(curl --fail --location)
if [[ -v GH_TOKEN ]]; then
  CURL+=(--oauth2-bearer "$GH_TOKEN")
fi
CURL+=(-- "$URL")
"${CURL[@]}"
```

- When there are multiple branches, use comprehensive enumeration instead of `if/elif` chains:

```bash
case "$VARIABLE" in
...)
  # ...
  ;;
*)
  set -x
  exit 2
  ;;
esac
```

- Use `printf -- '%s' ...` instead of `echo` for single statements.
  - Use `printf -v VAR -- '<fmt>' args` to assign formatted output to a variable without a subshell.
  - For multiline statements with interpolations, use heredocs:

```bash
tee <<- EOF
$VARIABLE_1
... $VARIABLE_2
EOF >&2
```

- Use `(( ))` for math comparisons, not `[[ ]]`.

- Use `exec --` for early exit if possible, to simplify control flow.

- Avoid inlining complicated `jq`, `awk`, or `sed` scripts. Create a standalone `.jq`, `.awk`, `.sed` executable instead.
  - If inlining is desired, always use a heredoc.

```bash
read -r -d '' -- JQ <<- 'JQ' || true
.[] | to_entries[] | [.key] + .value | join("\n")
JQ

jq --raw-output0 "$JQ" < 'example.json'
```

- Use the following prelude for bash scripts:

```bash
#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
```

- For bash scripts under `~/work/` and `~/work.localized/`, use this prelude instead:

```bash
#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar
```

- When handling unexpected script inputs, prefer `set -x; exit 2` (also shown in the `case` catch-all above).

- Invoke nearby scripts by relative path:

```bash
SELF="$(realpath -- "$0")"
BASE="${SELF%/*}"

exec -- "$BASE/<script-name.sh>" '<arg1>' '<arg2>' '...'
```

- Pipe through conditional blocks — `if`/`case`/`while` can appear mid-pipeline:

```bash
grep --recursive -e '...' --null | if [[ -v SSH_CONNECTION ]]; then
  # ...
else
  tee
fi | xargs --no-run-if-empty --null -I % --max-procs=0 -- tree -- %
```

- Use env-var self-recursion to re-enter the same script in a different mode. Name the flag after the context: `RECUR=`, `LOCKED=`, `UNDER=`, etc.
  - Useful for `flock`, `xargs`, and mode-switching.

```bash
FILE="$1"
if [[ -v RECUR ]]; then
  isort -- "$FILE"
  exec -- black -- "$FILE"
fi

RECUR=1 flock "$FILE" "$0" "$@"
```

- Use `shift -- <count>` after consuming positional args.

- Use `shopt -u failglob` after the prelude when globs may legitimately match nothing.

- Use `readarray -t` to capture multi-line output into arrays, not subshell loops or word splitting.

- Use parameter expansion `${var%%pat}` / `${var##pat}` / `${var%pat}` / `${var#pat}` over `basename`, `dirname`, or `cut` for string decomposition.

```bash
BASENAME="${URI##*/}"
BASENAME="${BASENAME%.git}"
DIR="${FILE%/*}"
```

- Use `command -v --` or `hash --` to check command existence, not `which` or `type`.

- Use `set -a` / `set +a` to scope exports when sourcing a file.
