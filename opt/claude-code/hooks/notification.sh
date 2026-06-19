#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STORE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scheduled_tasks.json"
JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"

case "$EVENT" in
Notification)
  TYPE="$(jq -e --raw-output '.notification_type' <<< "$JSON")"
  case "$TYPE" in
  permission_prompt)
    ;;
  idle_prompt)
    if jq --exit-status '.agent_type' <<< "$JSON" > /dev/null; then
      exit
    fi
    ;;
  *)
    set -x
    exit 2
    ;;
  esac
  MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"
  ;;
Stop | StopFailure)
  if [[ -f $STORE ]]; then
    SESSION_ID="$(jq --raw-output '.session_id' <<< "$JSON")"
    if jq --exit-status --arg s "$SESSION_ID" 'any(.. | objects; .sessionId? == $s)' "$STORE" > /dev/null 2>&1; then
      exit
    fi
  fi
  MESSAGE="$(jq -e --raw-output '.last_assistant_message' <<< "$JSON")"
  ;;
*)
  set -x
  exit 2
  ;;
esac

if [[ -v TMUX_PANE ]]; then
  TITLE="$(tmux display-message -t "$TMUX_PANE" -p '#{pane_title}')"
else
  TITLE="Chatty ~ $(basename -- "${CLAUDE_PROJECT_DIR:="$PWD"}")"
fi

jq --null-input --arg title "$TITLE" --arg message "$MESSAGE" '{$title, $message}' | "${0%/*}/../libexec/notify.sh"
