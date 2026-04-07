#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
CMD_LINE="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": $decision,
    "permissionDecisionReason": "⚠️ " + $reason
  }
}
JQ

DECISION='ask'
case "$CMD_LINE" in
'bash '* | 'dash '* | 'fish '* | 'pwsh '* | 'sh '* | 'zsh '*)
  REASON='consider not doing nested shell scripts'
  ;;
'curl '* | 'wget '*)
  DECISION='deny'
  REASON='consider using an alternative, like pip install, npm install, etc'
  ;;
'git push '*--force* | 'git push '*-f*)
  REASON='review force pushing'
  ;;
*)
  exit
  ;;
esac

exec -- jq -e --null-input --arg decision "$DECISION" --arg reason "$REASON" "$JQ"
