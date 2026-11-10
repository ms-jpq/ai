#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${GOOGLE_MODEL?}"
: "${GOOGLE_API_KEY?}"

CURL=(
  curl.sh
  'google'
  --no-buffer
  --json @-
  --url "${GOOGLE_BASE_URL:-"https://generativelanguage.googleapis.com"}/v1beta/models/$GOOGLE_MODEL:streamGenerateContent?key=$GOOGLE_API_KEY"
)

PREPARSE=(
  jq
  --exit-status
  --null-input
  --stream
  --unbuffered
  --compact-output
  'fromstream(1 | truncate_stream(inputs))'
)

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.candidates[].content.parts // [] | .[].text'
)

"${CURL[@]}" | "${PREPARSE[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
