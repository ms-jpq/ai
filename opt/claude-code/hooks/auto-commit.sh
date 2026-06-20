#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"
TRANSCRIPT="$(jq -e --raw-output '.transcript_path' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"
HISTORY="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.var/sessions/$SESSION_ID.md"

case "$EVENT" in
Stop | StopFailure)
  ;;
*)
  set -x
  exit 2
  ;;
esac

NOTES="$CWD/.notes"
if ! [[ -d $NOTES && -e "$NOTES/.git" ]]; then
  exit
fi

LIBEXEC="${0%/*}/../libexec/worktree"

jq --raw-output '.last_assistant_message // ""' <<< "$JSON" > "$NOTES/.LAST_MESSAGE.md"

if [[ $EVENT == Stop ]]; then
  declare -A -- LINKS=(
    [".HISTORY.md"]="$HISTORY"
    [".TRANSCRIPT.json"]="$TRANSCRIPT"
  )
  for DEST in "${!LINKS[@]}"; do
    if ! [[ -L "$NOTES/$DEST" ]]; then
      ln -sTnfr -- "${LINKS[$DEST]}" "$NOTES/$DEST"
    fi
  done
fi

SUBJECT="$(head -n 1 -- "$NOTES/.LAST_MESSAGE.md")"
"$LIBEXEC/commit-on-change.sh" "$NOTES" "stop${SUBJECT:+ ~> $SUBJECT}"
