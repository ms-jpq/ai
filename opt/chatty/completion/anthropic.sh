#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# shellcheck disable=SC2154
CURL=(
  curl.sh
  'anthropic'
  --header 'Anthropic-Version: 2023-06-01'
  --header 'Anthropic-Beta: mcp-client-2025-04-04'
  --header "X-API-Key: $ANTHROPIC_API_KEY"
  --no-buffer
  --json @-
  -- 'https://api.anthropic.com/v1/messages'
)

read -r -d '' -- JQ <<- 'JQ' || true
. as $i
| if .type == "content_block_stop"
  then
    "\n"
  else
    $i.content_block // $i.delta // {} | .text // empty
  end
JQ

PARSE=(
  jq
  --exit-status
  --join-output
  --unbuffered
  "$JQ"
)

"${CURL[@]}" | llm-pager.sh "$@" "${PARSE[@]}"
