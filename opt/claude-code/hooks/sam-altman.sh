#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
_CMD_LINE="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": $decision,
    "permissionDecisionReason": $reason
  }
}
JQ

DECISION='ask'

case "$_CMD_LINE" in
bash' '*)
  REASON=''
  ;;
find' '*' '-x)
  REASON=''
  ;;
*)
  exit
  ;;
esac

exec -- jq -e --arg decision "$DECISION" --arg reason "$REASON" "$JQ" > /dev/null
