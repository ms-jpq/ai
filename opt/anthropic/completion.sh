#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'anthropic'
  --header 'Anthropic-Version: 2023-06-01'
  --header "X-API-Key: $ANTHROPIC_API_KEY"
  --no-buffer
  --json @-
  -- 'https://api.anthropic.com/v1/messages'
)

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.content_block // .delta // {} | .text // empty'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
