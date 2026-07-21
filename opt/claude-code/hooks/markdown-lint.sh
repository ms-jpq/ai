#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"
read -r -d '' -- JQ <<- 'JQ' || true
.tool_calls[]? | select(.tool_name | IN("Write", "Edit", "MultiEdit")) | .tool_input.file_path | select(endswith(".md"))
JQ

CTX="$(jq --raw-output0 "$JQ" <<< "$JSON" | sort -z --unique | xargs -r --null -I % --max-procs=0 -- "${0%/*}/../libexec/lint-d.sh" % 2>&1 || true)"
read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolBatch",
    "additionalContext": $context
  }
}
JQ

exec -- jq -e --null-input --arg context "$CTX" "$JQ"
