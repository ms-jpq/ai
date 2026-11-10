#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${LLAMA_API_BASE?}"

CURL=(
  curl.sh
  'llama'
  --
  "${LLAMA_API_BASE%/}/models"
)

PARSE=(
  jq
  --exit-status
  --sort-keys
  '.'
)

"${CURL[@]}" | "${PARSE[@]}"
