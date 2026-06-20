#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"
FILE="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": $decision,
    "permissionDecisionReason": $reason
  }
}
JQ

case "$FILE" in
"$CWD"/.exp/*)
  DECISION=allow
  REASON='✅ .exp/ auto-approved'
  ;;
"$CWD"/.notes/'@root'/* | "$CWD"/.notes/'@peers'/*)
  DECISION=deny
  REASON='🚫 .notes/ symlink — points to state owned by another'
  ;;
"$CWD"/.notes/*)
  DECISION=allow
  REASON='✅ .notes/ auto-approved'
  ;;
*)
  exit
  ;;
esac

exec -- jq -e --null-input --arg decision "$DECISION" --arg reason "$REASON" "$JQ"
