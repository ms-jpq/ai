# Shell Scripting

- Prelude for bash scripts:

```bash
#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
```

- Bash 3 compatible prelude for scripts under `~/work/` and `~/work.localized/`:

```bash
#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar
```

- Long flags over short (`--delimiter` not `-d`). `--` to terminate option parsing (`cd -- "$DIR"`, `declare -A -- VAR=()`).

```bash
"${CMD[@]}" | "${JQ[@]}" "$JQ_SCRIPT" | awk -v key="$KEY" "$AWK" | column -t | sed -E -e '...'
```

- Reusable arguments in arrays: `GREP=(grep --recursive ...)`, `${GREP[@]}`.
  - For long or numerous arguments (over `\ ` escaping)
  - For code reuse across invocations (over functions)
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

- `case` catch-all (`*`) exits with `set -v; exit 2` for unexpected inputs.

```bash
case "$VARIABLE" in
...)
  # ...
  ;;
*)
  set -v
  exit 2
  ;;
esac
```

- Inline code over functions. Explicit error checks over traps. Both functions and traps obscure error propagation under `set -e`.

- Null bytes as delimiters where possible — `find ... -print0 | xargs --null ...`

- Standalone `.jq`, `.awk`, `.sed` executables over inlined scripts.
  - Heredoc when inlining.

```bash
read -r -d '' -- JQ <<- 'JQ' || true
.[] | to_entries[] | [.key] + .value | join("\n")
JQ

jq --raw-output0 "$JQ" < 'example.json'
```

- Pipe through conditional blocks — `if`/`case`/`while` can appear mid-pipeline:

```bash
grep --recursive -e '...' --null | if [[ -v SSH_CONNECTION ]]; then
  '...'
else
  tee
fi | xargs --no-run-if-empty --null -I % --max-procs=0 -- tree -- %
```

- `printf -- '%s' ...` over `echo` for single statements.
  - `printf -v VAR -- '<fmt>' args` to assign formatted output without a subshell.
  - Heredocs for multi-line statements with interpolations:

```bash
tee <<- EOF
$VARIABLE_1
... $VARIABLE_2
EOF >&2
```

- Redirects over `echo`/`printf` pipes.
  - `jq <<< "$JSON"` over `echo "$JSON" | jq`
  - `cmd < "$FILE"` or `$(< "$FILE")` over `cat "$FILE" | cmd`

- `exec --` when no code follows.

- `$var` over `${var}` unless braces are needed for disambiguation (`${var}_suffix`).

- Parameter expansion (`${var%%pat}` / `${var##pat}` / `${var%pat}` / `${var#pat}`) over `basename`, `dirname`, or `cut` for string decomposition.

```bash
BASENAME="${URI##*/}"
BASENAME="${BASENAME%.git}"
DIR="${FILE%/*}"
```

- `(( ))` for math comparisons. `[[ ]]` reserved for string and file tests.

- `readarray -t` to capture multi-line output into arrays. Single process, newline-safe — subshell loops and word splitting both mangle whitespace.

- `${ARRAY[*]}` over `${ARRAY[0]}` to stringify a single-element array.

- Env-var self-recursion to re-enter the same script in a different mode. Name the flag after the context: `RECUR=`, `LOCKED=`, `UNDER=`, etc.
  - For `flock`, `xargs`, and mode-switching.

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

- `shift -- <count>` after consuming positional args.

- `shopt -u failglob` after the prelude when globs may legitimately match nothing.

- `command -v --` or `hash --` to check command existence.

- `set -a` / `set +a` to scope exports when sourcing an env file.

- No `\`-continuation. Arrays for conditional extension.
