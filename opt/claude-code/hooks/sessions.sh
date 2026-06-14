#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="${0%/*}"
ROOT="$(realpath -- "$BASE/../../..")"
SESSIONS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.var/sessions"
MD="$SESSIONS/$SESSION_ID.md"
mkdir -p -- "$SESSIONS"

# shellcheck disable=SC2016
NOTIFY=(jq -e --compact-output --argjson n 28 '{ title: null, message: (.[$field] | if length > $n then .[:$n] + "…" else . end) }')

case "$EVENT" in
SessionStart)
  if [[ -v TMUX_PANE ]]; then
    tmux set-option -t "$TMUX_PANE" -p @claude_session "$SESSION_ID"

    printf -v REVIEW -- '%q ' env -- CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" "$ROOT/opt/claude-code/libexec/review-diffs.sh"
    printf -v HIST -- '%q ' env -- CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" "$ROOT/opt/claude-code/libexec/read-session.sh"
    tmux bind-key f run-shell -- "$HIST"
    tmux bind-key F run-shell -- "$REVIEW"
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
    exec -- flock "$MD" jq -e --raw-output '["# >>> plan <<<", "", .tool_response.plan, "", "---", ""][]' <<< "$JSON" >> "$MD"
    ;;
  *)
    exit
    ;;
  esac
  ;;
UserPromptSubmit)
  ROLE='user'
  ;;
Stop)
  ROLE='assistant'
  "${NOTIFY[@]}" --arg field 'last_assistant_message' <<< "$JSON" | "$BASE/notification.sh"
  ;;
StopFailure)
  ROLE='assistant'
  "${NOTIFY[@]}" --arg field 'error' <<< "$JSON" | "$BASE/notification.sh"
  ;;
*)
  set -v
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
exec -- flock "$MD" "${JQ[@]}" <<< "$JSON" >> "$MD"
