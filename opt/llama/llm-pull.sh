#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if (($#)); then
  MODEL="$*"
else
  URI='https://huggingface.co/models?library=gguf'
  printf -- '%s\n' "$URI" >&2
  exec -- open -- "$URI"
fi

: "${MCP_DOMAIN?}"
: "${LLAMA_API_KEY?}"

CURL=(
  curl.sh
  'llama'
  --no-buffer
  --json @-
  --header "X-Api-Key: $LLAMA_API_KEY"
  --no-fail
  --fail-with-body
  -- "https://litellm.$MCP_DOMAIN/models"
)

PARSE=(
  jq
  --exit-status
  --sort-keys
  '.'
)

jq --null-input --arg model "$MODEL" '{ model: $model }' | "${CURL[@]}" | "${PARSE[@]}"
