#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# shellcheck disable=SC2154
CURL=(
  curl.sh
  'openai'
  --no-buffer
  --header "Authorization: Bearer $OPENAI_API_KEY"
  --json @-
  -- 'https://api.openai.com/v1/responses'
)

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.delta // empty'
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
