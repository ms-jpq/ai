#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
TOOL="$(jq -e --raw-output '.tool_name' <<< "$JSON")"

case "$TOOL" in
request_user_input)
  ;;
*)
  exit
  ;;
esac

read -r -d '' -- JSON <<- 'JSON' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny"
  }
}
JSON

exec -- jq -e --null-input "$JSON"
