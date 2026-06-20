#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

TOOL="$(jq -e --raw-output '.tool_name' <<< "$JSON")"

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": $decision,
    "permissionDecisionReason": ("⚠️ " + $reason)
  }
}
JQ

DECISION=deny
case "$TOOL" in
WebSearch)
  REASON='use searx for search, or crawl4ai to fetch'
  ;;
WebFetch)
  REASON='use crawl4ai to fetch, or searx for search'
  ;;
*)
  exit
  ;;
esac

exec -- jq -e --null-input --arg decision "$DECISION" --arg reason "$REASON" "$JQ"
