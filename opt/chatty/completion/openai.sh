#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'openai'
  --no-buffer
  --json @-
  --url "${OPENAI_BASE_URL:-"https://api.openai.com"}/v1/responses"
)

# shellcheck disable=SC2154
if [[ -n $LITELLM_API_KEY ]]; then
  CURL+=(
    --header "X-Api-Key: $OPENAI_API_KEY"
    --header "Authorization: Bearer $LITELLM_API_KEY"
  )
else
  CURL+=(
    --header "Authorization: Bearer $OPENAI_API_KEY"
  )
fi

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  'if .type == "response.mcp_call_arguments.delta" then empty else .delta // empty end'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
