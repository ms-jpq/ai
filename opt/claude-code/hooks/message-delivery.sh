#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name | strings' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd | strings' <<< "$JSON")"

if ROOT="$(git -C "$CWD" rev-parse --show-toplevel 2> /dev/null)"; then
  MESSAGES="$ROOT/.notes/messages"
else
  MESSAGES="$CWD/.notes/messages"
fi

case "$EVENT" in
PostToolBatch | UserPromptSubmit | Stop)
  AGENT="$(jq --raw-output '.agent_id // ""' <<< "$JSON")"
  if [[ -n $AGENT ]]; then
    exit
  fi
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

umask 077
mkdir -p -- "$MESSAGES"
CONTEXT="$(find "$MESSAGES" -maxdepth 1 -type f -exec cat -- '{}' ';' -delete)"

if [[ -z $CONTEXT ]]; then
  exit
fi

exec -- jq -e --null-input --arg event "$EVENT" --arg context "$CONTEXT" "$JQ"
