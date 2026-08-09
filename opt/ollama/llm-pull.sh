#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if (($#)); then
  MODEL="$*"
else
  URI='https://ollama.com/library'
  printf -- '%s\n' "$URI" >&2
  exec -- open -- "$URI"
fi

: "${OLLAMA_API_BASE?}"

CURL=(
  curl.sh
  'ollama'
  --no-buffer
  --json @-
  -- "$OLLAMA_API_BASE/api/pull"
)

PARSE=(
  jq
  --exit-status
  --sort-keys
  '.'
)

jq --null-input --arg model "$MODEL" '{ model: $model }' | "${CURL[@]}" | "${PARSE[@]}"
