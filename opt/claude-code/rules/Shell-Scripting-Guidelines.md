# Shell Scripting Guidelines

- **Always** run `shellcheck '<script>.sh'`, **always** run `shfmt.sh '<script>.sh'`

- Do not forget to add a shebang like `#!/usr/bin/env -S -- nodejs`, followed by `chmod +x`.

- Always use long form flags, like `--delimiter` instead of `-d`, when available, use `--` to stop argument parse errors

- Always use null byte as delimiter if possible, i.e. `find ... -print0 | xargs --null ...`

- Do capture re-usable arguments in an array to invoke later, ie. `GREP=(grep --recursive ...)`, `${GREP[@]}`.
  - Do this instead of `\ ` escaping for long / many arguments
  - Do this instead of functions for code re-using

- Avoid writing functions and traps these make error propagation harder.

- Avoid passing variables as stdin with pipes, instead of `echo "$JSON" | jq`, do `jq <<< "$JSON"`

- When there are multiple branches, use comphensive enumeration instead of `if ...; then ...; elif ...; then ...`, do:

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

- Avoid writing `echo` statements, use `printf -- '%s' ...` instead for single statements, for multiline statements with interpolations see:

```bash
tee <<- EOF
$VARIABLE_1
... $VARIABLE_2
EOF > &2
```

- Avoid using `[[ ]]` for math comparisons, use `(( ))` instead.

- Avoid inlining complicated scripts such as that of `jq` and `awk`. Create a `.awk`, `.jq`, `.sed` executable script instead, and call them.
  - If inlining is desired, always use heredoc.

```bash
  read -r -d '' -- JQ <<- 'JQ' || true
.[] | to_entries[] | [.key] + .value | join("\n")
JQ

jq --raw-output0 "$JQ" < 'example.json'
```

- Always use the following prelude for bash scripts

```bash
#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar
```

- When handling unexpected script inputs, prefer exit code 2 like so:

```bash
if '...'; then
  set -x
  exit 2
fi
```

- When invoking scripts that are relatively close on the file system, call them by relative location like so:

```bash
SELF="$(realpath -- "$0")"
BASE="${SELF%/*}"

exec -- "$BASE/<script-name.sh>" '<arg1>' '<arg2>' '...'
```

- Really take advantage of everything in `bash` being pipe-able, an example:

```bash
grep --recursive -e '...' --null | if [[ -v SSH_CONNECTION ]]; then
  # ...
else
  tee
fi | xargs --no-run-if-empty --null -I % --max-procs=0 -- tree -- %
```

- Think out side of the box with control flows, for example, when `flock` was needed to lock down a file, to prevent race issues, use recursion:

```bash
FILE="$1"
if [[ -v RECUR ]]; then
  isort -- "$FILE"
  exec -- black -- "$FILE"
fi

RECUR=1 flock "$FILE" "$0" "$@"
```
