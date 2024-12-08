#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'ollama'
  --
  "$OLLAMA_API_BASE/api/ps"
  "$OLLAMA_API_BASE/api/tags"
)

PARSE=(
  jq
  --exit-status
  --sort-keys
  '.'
)

"${CURL[@]}" | "${PARSE[@]}"
