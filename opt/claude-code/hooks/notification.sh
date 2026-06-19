#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar

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
