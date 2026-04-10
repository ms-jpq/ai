#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
FILE_PATH="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"

case "$FILE_PATH" in
*.sh) ;;
*)
  exit 0
  ;;
esac

{
  shfmt --simplify --binary-next-line --space-redirects --indent=2 --write -- "$FILE_PATH"
  shellcheck -- "$FILE_PATH"
} >&2
