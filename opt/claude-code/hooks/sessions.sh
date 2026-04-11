#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"

BASE="${0%/*}"
ROOT="$(realpath -- "$BASE/../../..")"
SESSIONS="$ROOT/var/sessions"
MD="$SESSIONS/$SESSION_ID.md"

case "$EVENT" in
SessionStart)
  if [[ -n $CLAUDE_ENV_FILE ]]; then
    {
      printf -- '%q ' 'export' '--' "__CLAUDE_SESSION_ID=$SESSION_ID"
      printf -- '\n'
    } >> "$CLAUDE_ENV_FILE"
  fi

  if [[ -v TMUX_PANE ]]; then
    tmux set-option -t "$TMUX_PANE" -p @claude_session "$SESSION_ID"

    printf -v REVIEW -- '%q' "$ROOT/opt/claude-code/libexec/review-diffs.sh"
    printf -v HIST -- '%q' "$ROOT/opt/claude-code/libexec/read-session.sh"
    tmux bind-key f run-shell -- "$REVIEW"
    tmux bind-key F run-shell -- "$HIST"
  fi
  exec -- find "$SESSIONS" -mindepth 1 -mtime +30 -delete
  ;;
SessionEnd)
  if INDEX="$("$BASE/../libexec/session-file.sh" "$PWD")"; then
    rm -fr -- "$INDEX"
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
  jq -e --compact-output '{ title: null, message: (.last_assistant_message | if length > 28 then .[:28] + "…" else . end) }' <<< "$JSON" | "$BASE/notification.sh"
  ;;
*)
  set -x
  exit 2
  ;;
esac

if INDEX="$("$BASE/../libexec/session-file.sh" "$PWD")"; then
  printf -- '%s' "$SESSION_ID" > "$INDEX"
fi

MD="$SESSIONS/$SESSION_ID.md"
# shellcheck disable=2016
JQ=(
  jq -e --raw-output
  --arg role "$ROLE"
  '["# >>> \($role) <<<", "", .prompt // .last_assistant_message, "", "---", ""][]'
)

touch -- "$MD"

# shellcheck disable=SC2094
exec -- flock "$MD" "${JQ[@]}" <<< "$JSON" >> "$MD"
