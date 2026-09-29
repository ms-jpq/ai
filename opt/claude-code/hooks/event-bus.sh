#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name | strings' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd | strings' <<< "$JSON")"

if ROOT="$(git -C "$CWD" rev-parse --show-toplevel 2> /dev/null)"; then
  MESSAGES="$ROOT/.notes/events"
else
  MESSAGES="$CWD/.notes/events"
fi
SIGNAL="$MESSAGES/.events-ready"

if jq -e '.agent_id' <<< "$JSON" > /dev/null; then
  exit
fi

umask 077
mkdir -p -- "$MESSAGES"
CONSUME=(
  flock -- "$MESSAGES"
  find "$MESSAGES"
  -maxdepth 1
  -type f
  ! -name '.*'
  -exec cat -- '{}' ';'
  -delete
)

case "$EVENT" in
SessionStart)
  touch -- "$SIGNAL"
  CONTEXT="$("${CONSUME[@]}")"
  read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "watchPaths": [$signal],
    "additionalContext": $context
  }
}
JQ
  exec -- jq -e --null-input --arg signal "$SIGNAL" --arg context "$CONTEXT" "$JQ"
  ;;
FileChanged)
  FILE="$(jq -e --raw-output '.file_path' <<< "$JSON")"
  if [[ $FILE != "$SIGNAL" ]]; then
    exit
  fi
  CONTEXT="$("${CONSUME[@]}")"
  if [[ -n $CONTEXT ]]; then
    printf -- '%s\n' "$CONTEXT" >&2
    exit 2
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
