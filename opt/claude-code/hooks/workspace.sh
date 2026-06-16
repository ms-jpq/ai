#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"
TRANSCRIPT="$(jq -e --raw-output '.transcript_path' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"
HISTORY="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.var/sessions/$SESSION_ID.md"

SELF="$(realpath -- "$0")"
LIBEXEC="${SELF%/*}/../libexec/worktree"
WS=(env -C "$CWD" -- "$LIBEXEC/pool.sh")

case "$EVENT" in
SessionStart)
  exec -- "${WS[@]}" init
  ;;
WorktreeCreate)
  NAME="$(jq -e --raw-output '.name' <<< "$JSON")"
  exec -- "${WS[@]}" add "$NAME"
  ;;
WorktreeRemove)
  WORKTREE="$(jq -e --raw-output '.worktree_path' <<< "$JSON")"
  exec -- "${WS[@]}" remove "${WORKTREE##*/}"
  ;;
*)
  ;;
esac

NOTES="$CWD/.notes"
if ! [[ -L $NOTES && -d $NOTES ]]; then
  exit
fi

declare -A -- MAP=(
  [PostToolUse]=running
  [PostToolUseFailure]=running
  [PreToolUse]=running
  [UserPromptSubmit]=running
  [Notification]=parked
  [Stop]=parked
  [StopFailure]=parked
)

if [[ -v MAP[$EVENT] ]]; then
  "${WS[@]}" set-status "${CWD##*/}" "${MAP[$EVENT]}"
fi

case "$EVENT" in
StopFailure)
  jq --raw-output '.last_assistant_message' <<< "$JSON" > "$NOTES/LAST_MESSAGE.md"
  ;;
Stop)
  jq --raw-output '.last_assistant_message' <<< "$JSON" > "$NOTES/LAST_MESSAGE.md"

  declare -A -- LINKS=(
    ["HISTORY.md"]="$HISTORY"
    ["transcript.json"]="$TRANSCRIPT"
  )
  for DEST in "${!LINKS[@]}"; do
    if ! [[ -L "$NOTES/$DEST" ]]; then
      ln -sTnf -- "${LINKS[$DEST]}" "$NOTES/$DEST"
    fi
  done
  ;;
PostToolUse | PostToolUseFailure | PreToolUse | UserPromptSubmit | Notification)
  ;;
*)
  set -x
  exit 2
  ;;
esac
