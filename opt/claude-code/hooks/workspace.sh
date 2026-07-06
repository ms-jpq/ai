#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
CWD="$(jq -e --raw-output '.cwd' <<< "$JSON")"

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
if ! [[ -L $NOTES ]]; then
  exit
fi

MAIN_AGENT='wt-worker'
AGENT_TYPE="$(jq --raw-output '.agent_type // ""' <<< "$JSON")"
if [[ $AGENT_TYPE != "$MAIN_AGENT" ]]; then
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
