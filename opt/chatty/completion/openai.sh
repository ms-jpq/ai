#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# shellcheck disable=SC2154
CURL=(
  curl.sh
  'openai'
  --no-buffer
  --json @-
  --header "Authorization: Bearer $OPENAI_API_KEY"
)

if [[ -n $LITELLM_API_KEY ]]; then
  CURL+=(---header "X-Litellm-Api-Key: $LITELLM_API_KEY")
fi

CURL+=(-- "${OPENAI_BASE_URL:-"https://api.openai.com"}/v1/responses")

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  'if .type == "response.mcp_call_arguments.delta" then empty else .delta // empty end'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
