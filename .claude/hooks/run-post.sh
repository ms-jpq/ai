#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

FILE_PATH="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"

case "$FILE_PATH" in
*.json)
  TMP="$(mktemp)"
  if jq --sort-keys -- . "$FILE_PATH" > "$TMP"; then
    exec -- mv -f -- "$TMP" "$FILE_PATH"
  else
    rm -f -- "$TMP"
    exit 2
  fi
  ;;
*)
  exit 0
  ;;
esac >&2
