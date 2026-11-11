#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${MCP_DOMAIN?}"
: "${LLAMA_API_KEY?}"

CURL=(
  curl.sh
  'llama'
  --no-buffer
  --json @-
  --header "X-Api-Key: $LLAMA_API_KEY"
  --url "https://litellm.$MCP_DOMAIN/v1/chat/completions"
)

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.choices[]?.delta.content // empty'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
