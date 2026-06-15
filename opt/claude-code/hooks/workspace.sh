#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

declare -A -- MAP=(
  [PostToolUse]=running
  [PostToolUseFailure]=running
  [PreToolUse]=running
  [UserPromptSubmit]=running
  [Notification]=parked
  [Stop]=parked
  [StopFailure]=parked
)

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

SELF="$(realpath -- "$0")"
WS=(env -C "$CWD" -- "${SELF%/*}/../libexec/worktree/pool.sh")

if [[ -v MAP[$EVENT] ]] && [[ -L "$CWD/.notes" ]]; then
  "${WS[@]}" set-status "${CWD##*/}" "${MAP[$EVENT]}"
fi

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
Stop)
  SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"
  HISTORY="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.var/sessions/$SESSION_ID.md"
  TRANSCRIPT="$(jq -e --raw-output '.transcript_path' <<< "$JSON")"

  if [[ -d "$CWD/.notes" ]]; then
    ln -sTnf -- "$HISTORY" "$CWD/.notes/HISTORY.md"
    ln -sTnf -- "$TRANSCRIPT" "$CWD/.notes/transcript.json"
  fi
  ;;
PostToolUse | PostToolUseFailure | PreToolUse | UserPromptSubmit | Notification | StopFailure)
  ;;
*)
  set -x
  exit 2
  ;;
esac
