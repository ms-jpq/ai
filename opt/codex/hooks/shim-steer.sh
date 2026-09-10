#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

exit

# CMD_LINE="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"
#
# read -r -d '' -- JQ <<- 'JQ' || true
# {
#   "hookSpecificOutput": {
#     "hookEventName": "PreToolUse",
#     "permissionDecision": "deny",
#     "permissionDecisionReason": ("⚠️ " + $reason)
#   }
# }
# JQ
#
# exec -- jq -e --null-input --arg reason "$REASON" "$JQ"