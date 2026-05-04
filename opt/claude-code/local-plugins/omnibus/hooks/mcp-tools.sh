#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

TOOL_NAME="$(jq -e --raw-output '.tool_name' <<< "$JSON")"

case "$TOOL_NAME" in
mcp__plugin_omnibus_crawl4ai__* | mcp__plugin_omnibus_playwright__* | mcp__plugin_omnibus_searx__searxng_web_search)
  DECISION=allow
  REASON='allowlisted by omnibus plugin'
  ;;
mcp__plugin_omnibus_searx__web_url_read)
  DECISION=deny
  REASON='denylisted by omnibus plugin'
  ;;
*)
  exit 0
  ;;
esac

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": $decision,
    "permissionDecisionReason": $reason
  }
}
JQ

exec -- jq -e --null-input --arg decision "$DECISION" --arg reason "$REASON" "$JQ"
