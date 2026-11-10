#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${LLAMA_API_BASE?}"

CURL=(
  curl.sh
  'llama'
  --no-buffer
  --json @-
  --url "${LLAMA_API_BASE%/}/v1/chat/completions"
)

if [[ -n ${LITELLM_API_KEY:-} ]]; then
  CURL+=(--header "X-Litellm-Api-Key: $LITELLM_API_KEY")
fi

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.choices[]?.delta.content // empty'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
