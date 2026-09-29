#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"
BASE="$(realpath -- "${0%/*}/..")"
SCRATCHPAD="$(jq -e --raw-output '.scratchpad_dir' <<< "$JSON")"
STATE="$SCRATCHPAD/local-instruction-updates"
CHECKED="$STATE/checked"
INTERVAL=9

if jq -e '.agent_id' <<< "$JSON" > /dev/null; then
  exit
fi

if [[ ${RECUR:-} != 1 ]]; then
  mkdir -p -- "$STATE"
  RECUR=1 exec -- flock --exclusive -- "$STATE" "$0" "$@" <<< "$JSON"
fi

if [[ $EVENT == PostToolBatch ]] && { LAST_CHECK="$(< "$CHECKED")"; } 2> /dev/null; then
  if [[ $LAST_CHECK =~ ^[0-9]+$ ]] && ((EPOCHSECONDS - LAST_CHECK >= 0 && EPOCHSECONDS - LAST_CHECK < INTERVAL)); then
    exit
  fi
fi

SOURCES=("$CWD/.claude"/@(CLAUDE.md|rules|skills))
CONTEXT="$("$BASE/libexec/instruction-delta.sh" "$STATE/current" "${SOURCES[@]}")"
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

exec -- jq -e --null-input --arg event "$EVENT" --arg context "$CONTEXT" "$JQ"
