#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

TOOL_NAME="$(jq -e --raw-output '.tool_name' <<< "$JSON")"
NAME="$(sed -E -e 's#^mcp__plugin_omnibus_##' <<< "$TOOL_NAME")"

case "$NAME" in
searx__web_url_read)
  DECISION=deny
  REASON='use crawl4ai instead'
  ;;
searx__* | crawl4ai__*)
  DECISION=allow
  REASON='safe to use websearch'
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
