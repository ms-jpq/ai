# Shell Scripting Guidelines

- Use the following prelude for bash scripts:

```bash
#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
```

- For bash scripts under `~/work/` and `~/work.localized/`, use this prelude instead, for bash 3 compatibility:

```bash
#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar
```

- Always add a shebang like `#!/usr/bin/env -S -- nodejs`, and mark the file executable with `chmod +x`.

- Always use long form flags when available (`--delimiter` not `-d`) and `--` to terminate option parsing (`cd -- "$DIR"`).

- Prefer long streaming pipelines over intermediate variables or temp files. Each stage should do one thing.

```bash
"${CMD[@]}" | "${JQ[@]}" "$JQ_SCRIPT" | awk -v key="$KEY" "$AWK" | column -t | sed -E -e '...'
```

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

- When there are multiple branches, use comprehensive enumeration instead of `if/elif` chains.
  - Always include a catch-all (`*`) that exits with `set -x; exit 2` for unexpected inputs.

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

- Avoid writing functions and traps — these make error propagation harder.

- Always use null bytes as delimiters if possible, i.e. `find ... -print0 | xargs --null ...`

- Avoid inlining complicated `jq`, `awk`, or `sed` scripts. Create a standalone `.jq`, `.awk`, `.sed` executable instead.
  - If inlining is desired, always use a heredoc.

```bash
read -r -d '' -- JQ <<- 'JQ' || true
.[] | to_entries[] | [.key] + .value | join("\n")
JQ

jq --raw-output0 "$JQ" < 'example.json'
```

- Pipe through conditional blocks — `if`/`case`/`while` can appear mid-pipeline:

```bash
grep --recursive -e '...' --null | if [[ -v SSH_CONNECTION ]]; then
  # ...
else
  tee
fi | xargs --no-run-if-empty --null -I % --max-procs=0 -- tree -- %
```

- Avoid pointless `echo` or `printf` pipes — use redirects instead.
  - `jq <<< "$JSON"` instead of `echo "$JSON" | jq`
  - `cmd < "$FILE"` or `$(< "$FILE")` instead of `cat "$FILE" | cmd`

- Use `printf -- '%s' ...` instead of `echo` for single statements.
  - Use `printf -v VAR -- '<fmt>' args` to assign formatted output to a variable without a subshell.
  - For multiline statements with interpolations, use heredocs:

```bash
tee <<- EOF
$VARIABLE_1
... $VARIABLE_2
EOF >&2
```

- Prefer flags (`--quiet`, `--silent`) over `> /dev/null` to silence output.

- Prefer `$var` over `${var}` unless braces are needed for disambiguation (`${var}_suffix`).

- Use parameter expansion `${var%%pat}` / `${var##pat}` / `${var%pat}` / `${var#pat}` over `basename`, `dirname`, or `cut` for string decomposition.

```bash
BASENAME="${URI##*/}"
BASENAME="${BASENAME%.git}"
DIR="${FILE%/*}"
```

- Use `(( ))` for math comparisons, not `[[ ]]`.

- Use `readarray -t` to capture multi-line output into arrays, not subshell loops or word splitting.

- Use `exec --` for early exit of control flow if possible, to simplify control flow.

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

- Invoke nearby scripts by relative path:

```bash
SELF="$(realpath -- "$0")"
BASE="${SELF%/*}"

exec -- "$BASE/<script-name.sh>" '<arg1>' '<arg2>' '...'
```

- Use `shift -- <count>` after consuming positional args.

- Use `shopt -u failglob` after the prelude when globs may legitimately match nothing.

- Use `command -v --` or `hash --` to check command existence, not `which` or `type`.

- Use `set -a` / `set +a` to scope exports when sourcing an env file.

- Never use `[[ ... ]] || exit` or `[[ ... ]] && exit` — use `if [[ ... ]]; then exit; fi`.
