#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"
FILE="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"

if [[ $FILE != "$CWD"/.exp/* ]]; then
  exit
fi

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "✅ .exp/ auto-approved"
  }
}
JQ

exec -- jq -e --null-input "$JQ"
