#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${MCP_DOMAIN?}"
: "${LLAMA_API_KEY?}"

CURL=(
  curl.sh
  'llama'
  --header "X-Api-Key: $LLAMA_API_KEY"
  --
  "https://litellm.${MCP_DOMAIN}/models"
)

PARSE=(
  jq
  --exit-status
  --sort-keys
  '.'
)

"${CURL[@]}" | "${PARSE[@]}"
