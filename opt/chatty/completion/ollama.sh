#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# shellcheck disable=SC2154
CURL=(
  curl.sh
  'ollama'
  --no-buffer
  --json @-
  --url "$OLLAMA_API_BASE/api/chat"
)

if [[ -n $LITELLM_API_KEY ]]; then
  CURL+=(--header "X-Litellm-Api-Key: $LITELLM_API_KEY")
fi

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.message // {} | .content // empty'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
