#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# https://ollama.com/library
MODEL="$1"

CURL=(
  curl.sh
  'ollama'
  --no-buffer
  --json @-
  -- "$OLLAMA_URL/api/pull"
)

read -r -d '' -- JQ <<- 'JQ' || true
"\(.status) - \(try(.completed / .total) catch empty | . * 10000 | round / 100)% of \(.total)"
JQ

PARSE=(
  jq
  --exit-status
  --unbuffered
  --raw-output
  "$JQ"
)

jq --null-input --arg model "$MODEL" '{ model: $model }' | "${CURL[@]}" | "${PARSE[@]}"
