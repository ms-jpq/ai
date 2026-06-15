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
LIBEXEC="${SELF%/*}/../libexec/worktree"
WS=(env -C "$CWD" -- "$LIBEXEC/pool.sh")
PROMPT_SH="$LIBEXEC/prompt.sh"

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

  if [[ -L "$CWD/.notes" ]] && "$PROMPT_SH" drifted "$CWD/.notes/PROMPT.md"; then
    PROMPT=.notes/PROMPT.md
    "$PROMPT_SH" seal "$CWD/$PROMPT"

    read -r -d '' -- JQ <<- 'JQ' || true
{
  decision: "block",
  reason: $reason
}
JQ
    exec -- jq -e --null-input --arg reason "Your brief ($PROMPT) changed — re-read it and continue." "$JQ"
  fi
  ;;
PostToolUse | PostToolUseFailure | PreToolUse | UserPromptSubmit | Notification | StopFailure)
  ;;
*)
  set -x
  exit 2
  ;;
esac
