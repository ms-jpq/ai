#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'openai'
  --no-buffer
  --json @-
  -- 'https://api.openai.com/v1/chat/completions'
)

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.choices[].delta.content // empty'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
