#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
BASE="${0%/*}/.."
LINT="$BASE/libexec/lint-d.sh"

case "$EVENT" in
PostToolBatch)
  read -r -d '' -- JQ <<- 'JQ' || true
.tool_calls[]? | select(.tool_name | IN("Write", "Edit", "MultiEdit")) | .tool_input.file_path | select(endswith(".md"))
JQ

  CTX="$(jq --raw-output0 "$JQ" <<< "$JSON" | sort -z --unique | xargs -r --null -I % --max-procs=1 -- "$LINT" % 2>&1 || true)"
  ;;
*)
  set -x
  exit 2
  ;;
esac

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": $event,
    "additionalContext": $context
  }
}
JQ

exec -- jq -e --null-input --arg event "$EVENT" --arg context "$CTX" "$JQ"
