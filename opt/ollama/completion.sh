#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'ollama'
  --no-buffer
  --json @-
  -- "$OLLAMA_URL/api/chat"
)

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.message // {} | .content // empty'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
