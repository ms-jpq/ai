# Shell Scripting

## Defaults

- Prelude for bash scripts:

```bash
#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
```

- Prefer long flags unless the short form is conventional (`grep -e`, `sed -E -e`, `column -t`). `--` to terminate option parsing (`cd -- "$DIR"`, `declare -A -- VAR=()`).

```bash
"${CMD[@]}" | "${JQ[@]}" "$JQ_SCRIPT" | awk -v key="$KEY" "$AWK" | column -t | sed -E -e '...'
```

- `shopt -u failglob` after the prelude when globs may legitimately match nothing.

- Do not use backslash line continuations.

---

## Failure Semantics

- `case` catch-all (`*`) exits with `set -x; exit 2` for unexpected inputs.

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

- Inline one-use logic. Prefer explicit error checks to traps; functions invoked from conditional contexts and traps complicate `set -e` propagation.

- Do not suppress unexpected failures with `|| true`. Let the command fail or handle the failure explicitly with `if`.

  - Let it fail:

    ```bash
    OUTPUT="$(command)"
    ```

  - Handle it:

    ```bash
    if OUTPUT="$(command)"; then
      # ...
    else
      # ...
    fi
    ```

---

## Command Construction

- Use arrays for long or conditional command invocations, or when invoking the same command repeatedly: `GREP=(grep --recursive ...)`, `"${GREP[@]}"`.

  ```bash
  CURL=(curl --fail --location)
  if [[ -v GH_TOKEN ]]; then
    CURL+=(--oauth2-bearer "$GH_TOKEN")
  fi
  CURL+=(-- "$URL")
  "${CURL[@]}"
  ```

- `exec --` when no code follows.

- Resolve nearby scripts relative to the current script's directory:

  ```bash
  SELF="$(realpath -- "$0")"
  BASE="${SELF%/*}"

  exec -- "$BASE/<script-name.sh>" '<arg1>' '<arg2>' '...'
  ```

- `shift -- <count>` after consuming positional args.

- `command -v --` or `hash --` to check command existence.

- `set -a` / `set +a` to scope exports when sourcing an env file.

---

## Data Flow

- Use NUL delimiters for path streams: `find ... -print0 | xargs --null ...`

- Use `printf -- '%s' ...` for single-line output.

  - `printf -v VAR -- '<fmt>' args` to assign formatted output without a subshell.

  - Heredocs for multi-line statements with interpolations:

    ```bash
    tee <<- EOF
    $VARIABLE_1
    ... $VARIABLE_2
    EOF >&2
    ```

- Feed data through redirects instead of `echo` or `printf` pipelines.

  - `jq <<< "$JSON"` over `echo "$JSON" | jq`

  - `cmd < "$FILE"` or `$(< "$FILE")` over `cat "$FILE" | cmd`

- Capture multiline output with `readarray -t`; avoid word splitting and subshell loops.

  - Feed from `< <(printf -- %s "$VAR")` over `<<< "$VAR"`, when newline safety is required.

- Do not place fallible commands inside process substitutions consumed by `readarray`; their exit status does not propagate.

  ```bash
  OUTPUT="$(command)"
  readarray -t -- ARRAY < <(printf -- '%s' "$OUTPUT")
  ```

- Use `"${ARRAY[*]}"` to stringify single element arrays.

---

## Expansion

- `$var` over `${var}` unless braces are needed for disambiguation (`${var}_suffix`).

- Parameter expansion (`${var%%pat}` / `${var##pat}` / `${var%pat}` / `${var#pat}`) over `basename`, `dirname`, or `cut` for string decomposition.

  ```bash
  BASENAME="${URI##*/}"
  BASENAME="${BASENAME%.git}"
  DIR="${FILE%/*}"
  ```

- `(( ))` for math comparisons. `[[ ]]` reserved for string and file tests.

---

## Embedded Programs

- Pass trivial `sed`, `jq`, and `awk` programs directly as command arguments.

- Embed short, non-trivial programs with heredocs.

- Keep substantial or reusable programs in standalone `.sed`, `.jq`, or `.awk` executables.

  ```bash
  read -r -d '' -- JQ <<- 'JQ' || true
  .[] | to_entries[] | [.key] + .value | join("\n")
  JQ

  jq --raw-output0 "$JQ" < 'example.json'
  ```

---

## Process Control

- Pipe through conditional blocks — `if`/`case`/`while` can appear mid-pipeline:

  ```bash
  grep --recursive -e '...' --null | if [[ -v SSH_CONNECTION ]]; then
    '...'
  else
    tee
  fi | xargs --no-run-if-empty --null -I % --max-procs=0 -- tree -- %
  ```

- Use a context-named environment flag (`RECUR`, `LOCKED`, `UNDER`) when a script re-enters itself.

  ```bash
  FILE="$1"
  if [[ -v RECUR ]]; then
    isort -- "$FILE"
    exec -- black -- "$FILE"
  fi

  RECUR=1 flock "$FILE" "$0" "$@"
  ```
