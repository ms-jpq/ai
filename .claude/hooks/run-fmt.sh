#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

FILE_PATH="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"

case "$FILE_PATH" in
*.py)
  isort --quiet -- "$FILE_PATH" || exit 2
  black --quiet -- "$FILE_PATH" || exit 2
  ;;
*.md | *.yml | *.ts)
  FILE_PATH="$(realpath -- "$FILE_PATH")" || exit 2
  node_modules/.bin/prettier --write -- "$FILE_PATH" || exit 2
  ;;
*)
  exit 0
  ;;
esac >&2
