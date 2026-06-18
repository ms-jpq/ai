#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="${0%/*}"
LIBEXEC="$(realpath -- "$BASE/../libexec")"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SESSIONS="$CLAUDE_CONFIG_DIR/.var/sessions"
MD="$SESSIONS/$SESSION_ID.md"
mkdir -p -- "$SESSIONS"

case "$EVENT" in
SessionStart)
  if [[ -v TMUX_PANE ]]; then
    tmux set-option -t "$TMUX_PANE" -p @claude_session "$SESSION_ID"

    tmux bind-key f run-shell -- "env -- CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR@Q} ${LIBEXEC@Q}/read-session.sh"
  fi
  exec -- find "$SESSIONS" -mindepth 1 -mtime +30 -delete
  ;;
SessionEnd)
  if [[ -v TMUX_PANE ]]; then
    tmux set-option -t "$TMUX_PANE" -u -p @claude_session
  fi
  exit
  ;;
PostToolUse)
  TOOL="$(jq -e --raw-output '.tool_name' <<< "$JSON")"

  case "$TOOL" in
  ExitPlanMode)
    touch -- "$MD"
    # shellcheck disable=SC2094
    exec -- ~/.local/libexec/flock.sh "$MD" jq -e --raw-output '["# >>> plan <<<", "", .tool_response.plan, "", "---", ""][]' <<< "$JSON" >> "$MD"
    ;;
  *)
    exit
    ;;
  esac
  ;;
UserPromptSubmit)
  ROLE='user'
  ;;
Stop | StopFailure)
  ROLE='assistant'
  ;;
*)
  set -x
  exit 2
  ;;
esac

# shellcheck disable=2016
JQ=(
  jq -e --raw-output
  --arg role "$ROLE"
  '["# >>> \($role) <<<", "", .prompt // .last_assistant_message, "", "---", ""][]'
)

touch -- "$MD"

# shellcheck disable=SC2094
exec -- ~/.local/libexec/flock.sh "$MD" "${JQ[@]}" <<< "$JSON" >> "$MD"
