#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

TOOL="$(jq -e --raw-output '.tool_name' <<< "$JSON")"

case "$TOOL" in
request_user_input)
  REASON=''
  ;;
WebSearch)
  REASON='Use the searxng_web_search MCP for search.'
  ;;
WebFetch)
  REASON='Use the crawl4ai-md MCP to fetch.'
  ;;
*)
  exit
  ;;
esac

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": (
    {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny"
    }
    + if $reason == "" then {} else {"permissionDecisionReason": ("⚠️ " + $reason)} end
  )
}
JQ

exec -- jq -e --null-input --arg reason "$REASON" "$JQ"
