#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# shellcheck disable=SC2154
CURL=(
  curl.sh
  'ollama'
  --no-buffer
  -4k
  --json @-
  -- "$OLLAMA_PROXY_API_BASE/responses"
)

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  'if .type == "response.mcp_call_arguments.delta" then empty else .delta // empty end'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
