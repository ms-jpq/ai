# Shell Scripting

## Defaults

- Start bash scripts with the strict prelude.

  ```bash
  #!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

  set -o pipefail
  ```

- Keep the redundant `set -o pipefail`; shellcheck sees it.

- Declare mandatory variables at the entrypoint.

  ```bash
  set -o pipefail

  : "${REQUIRED_INPUT?}"
  : "${ANOTHER_REQUIRED_INPUT?}"
  ```

- `shopt -u failglob` after the prelude when globs may legitimately match nothing.

- Do not use backslash line continuations.

---

## Input State

- Use `case` to enumerate accepted input states; the catch-all (`*`) exits with `set -x; exit 2`.

  ```bash
  case "$MODE" in
  start | stop)
    run -- "$MODE"
    ;;
  *)
    set -x
    exit 2
    ;;
  esac
  ```

- Do not use `[[ -v NAME ]]`; Bash interprets its operand as a variable reference and evaluates array subscripts.

  - Test an optional string with `[[ -n ${NAME:-} ]]`; unset and empty mean absent.

- Do not attach `continue`, `break`, or `exit` to a `[[ ... ]]` test with `&&` or `||`; use an `if` block.

- `shift -- <count>` after consuming positional args.

---

## Failure Semantics

- Do not suppress unexpected failures with `|| true`. Let the command fail or handle the failure explicitly.

  ```bash
  OUTPUT="$(command || true)"
  ```

- Use explicit error checks to traps; functions invoked from conditionals and traps complicate `set -e`.

  ```bash
  if OUTPUT="$(command)"; then
    # ...
  else
    # ...
  fi
  ```

- `|| true` is only allowed for commands with a known nonzero success condition, such as `read -d ''` reaching heredoc EOF.

---

## Command Construction

- Prefer long flags unless the short form is conventional (`grep -e`, `sed -E -e`, `column -t`).

- Use `--` to terminate option parsing (`cd -- "$DIR"`, `declare -A -- VAR=()`).

- Use arrays for long, conditional, or repeated command invocations.

  ```bash
  CURL=(curl --fail --location)
  if [[ -n ${GH_TOKEN:-} ]]; then
    CURL+=(--oauth2-bearer "$GH_TOKEN")
  fi
  CURL+=(-- "$URL")
  "${CURL[@]}"
  ```

- Build long pipeline commands from arrays.

  ```bash
  "${CMD[@]}" | "${JQ[@]}" "$JQ_SCRIPT" | awk -v key="$KEY" "$AWK" | column -t | sed -E -e '...'
  ```

- `exec --` when no code follows.

- Resolve nearby scripts from the current script path:

  ```bash
  SELF="$(realpath -- "$0")"
  BASE="${SELF%/*}"

  exec -- "$BASE/tool.sh" "$@"
  ```

- `command -v --` or `hash --` to check command existence.

- `set -a` / `set +a` to scope exports when sourcing an env file.

---

## Data Flow

### Records and Newlines

- Bash data flow is line-oriented by default; choose record boundaries deliberately.

- Use newline-delimited records only when record values cannot contain newlines.

  - Use NUL delimiters where ever possible.

    ```bash
    find . -type f -print0 | xargs --null -- command
    ```

- Capture line records with `readarray -t`; avoid word splitting and subshell loops.

  ```bash
  readarray -t -- LINES < "$FILE"
  ```

  - Feed from `< <(printf -- '%s' "$VAR")` instead of `<<< "$VAR"` when a synthetic trailing newline would change the data.

- Do not place fallible commands inside process substitutions consumed by `readarray`; their exit status does not propagate.

  ```bash
  OUTPUT="$(command)"
  readarray -t -- ARRAY < <(printf -- '%s' "$OUTPUT")
  ```

### Redirects and Strings

- Feed data through redirects instead of `echo` or `printf` pipelines.

  - `jq <<< "$JSON"` over `echo "$JSON" | jq`

  - `cmd < "$FILE"` or `$(< "$FILE")` over `cat "$FILE" | cmd`

- Use `printf -- '%s' ...` for exact single-line output.

- `printf -v VAR -- '<fmt>' args` assigns formatted output without a subshell.

- Use heredocs for multi-line output.

  ```bash
  tee <<- EOF
  $VARIABLE_1
  ... $VARIABLE_2
  EOF >&2
  ```

- Use `"${ARRAY[*]}"` when the callee expects one string, even if the array currently has one element.

  ```bash
  ARGS=(--flag "$VALUE")
  printf -v COMMAND -- '%s' "${ARGS[*]}"
  ```

---

## Expansion

- `$var` over `${var}` unless braces are needed for disambiguation (`${var}_suffix`).

- Prefer parameter expansion over `basename`, `dirname`, or `cut` for string decomposition.

  ```bash
  BASENAME="${URI##*/}"
  BASENAME="${BASENAME%.git}"
  DIR="${FILE%/*}"
  ```

- `(( ))` for math comparisons. `[[ ]]` reserved for string and file tests.

---

## Embedded Programs

- Pass trivial `sed`, `jq`, and `awk` programs directly as command arguments.

- Embed short, non-trivial programs with heredocs, especially for jq and awk.

  ```bash
  read -r -d '' -- JQ <<- 'JQ' || true
  .[] | to_entries[] | [.key] + .value | join("\n")
  JQ

  jq --raw-output0 "$JQ" < 'example.json'
  ```

  - `|| true` is allowed here because `read -d ''` returns nonzero at heredoc EOF.

- Keep substantial or reusable programs in standalone `.sed`, `.jq`, or `.awk` executables.

---

## Process Control

- Use a context-named environment flag `RECUR` when a script re-enters itself.

  ```bash
  FILE="$1"
  if [[ ${RECUR:-} == 1 ]]; then
    isort -- "$FILE"
    exec -- black -- "$FILE"
  fi

  RECUR=1 flock "$FILE" "$0" "$@"
  ```

- Pipe through conditional blocks; `if`, `case`, and `while` can appear mid-pipeline.

  ```bash
  grep --recursive -e '...' --null | if [[ -n ${SSH_CONNECTION:-} ]]; then
    '...'
  else
    tee
  fi | xargs --no-run-if-empty --null -I % --max-procs=0 -- tree -- %
  ```

---

## Concurrency

- Never let concurrent work escape the foreground command tree; avoid background jobs so failures and signals propagate predictably.

  ```bash
  if [[ ${RECUR:-} == 1 ]]; then
    exec -- process-file "$1"
  fi

  find . -type f -print0 | xargs --null --no-run-if-empty --max-procs=0 -I {} -- env RECUR=1 "$0" {}
  ```
