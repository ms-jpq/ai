#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"
BASE="${0%/*}/.."
SESSIONS="$HOME/.local/opt/ai/var/sessions"
STATE="$SESSIONS/$SESSION_ID.instructions"
CHECKED="$STATE/checked"

if [[ ${RECUR:-} != 1 ]]; then
  mkdir -p -- "$STATE"
  RECUR=1 exec -- flock --exclusive -- "$STATE" "$0" "$@" <<< "$JSON"
fi

INTERVAL=10

if [[ $EVENT == PostToolUse ]] && { LAST_CHECK="$(< "$CHECKED")"; } 2> /dev/null; then
  if [[ $LAST_CHECK =~ ^[0-9]+$ ]] && ((EPOCHSECONDS - LAST_CHECK >= 0 && EPOCHSECONDS - LAST_CHECK < INTERVAL)); then
    exit
  fi
fi

CONTEXT="$("$BASE/libexec/instruction-delta.sh" "$STATE" "$BASE/AGENTS.md" "$BASE/rules" "$BASE/rules.d")"
printf -- '%s' "$EPOCHSECONDS" > "$CHECKED"

if [[ -z $CONTEXT ]]; then
  exit
fi

read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": $event,
    "additionalContext": $context
  }
}
JQ

jq -e --null-input --arg event "$EVENT" --arg context "$CONTEXT" "$JQ"
rm -- "$STATE/pending.txt"
