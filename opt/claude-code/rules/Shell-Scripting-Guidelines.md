# Shell Scripting Guidelines

- **Always** run `shellcheck`.

- Do not forget to add a shebang like `#!/usr/bin/env -S -- nodejs`, followed by `chmod +x`.

- Always use long form flags, like `--delimiter` instead of `-d`, when available, use `--` to stop argument parse errors

- Always use `null` byte as delimiter if possible, i.e. `find ... -print0 | xargs --null ...`

- Do capture re-usable arguments in an array to invoke later, ie. `GREP=(grep --recursive ...)`, `${GREP[@]}`.
  - Do this instead of `\ ` escaping for long / many arguments
  - Do this instead of functions for code re-using

- Avoid writing functions and traps these make error propagation harder.

- Avoid inlining complicated scripts such as that of `jq` and `awk`. Create a `.awk`, `.jq`, `.sed` executable script instead, and call them.

- When calling scripts that are relatively close on the file system,

```bash
SELF="$(realpath -- "$0")"
BASE="${SELF%/*}"

exec -- "$BASE/<script-name.sh>" '<arg1>' '<arg2>' '...'
```

- Take advantage of `bash`'s control flows being pipe-able, an example:

```bash
grep --recursive -e '...' --null | if [[ -v SSH_CONNECTION ]]; then
  # ...
else
  tee
fi | xargs --no-run-if-empty --null -I % --max-procs=0 -- tree -- %
```
