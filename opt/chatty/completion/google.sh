#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl.sh
  'ollama'
  --no-buffer
  --json @-
  -- "https://generativelanguage.googleapis.com/v1beta/models/$GEMINI_MODEL:streamGenerateContent?key=$GOOGLE_API_KEY"
)

PREPARSE=(
  jq
  --exit-status
  --stream
  --unbuffered
  --compact-output
  'fromstream(1|truncate_stream(inputs))'
)

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  '.candidates[].content.parts[].text'
)

"${CURL[@]}" | "${PREPARSE[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
