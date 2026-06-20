#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

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
    exit
    ;;
  esac
  MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"
  ;;
Stop | StopFailure)
  TRANSCRIPT="$(jq --raw-output '.transcript_path' <<< "$JSON")"

  if jq --raw-output '.promptSource // empty' "$TRANSCRIPT" 2> /dev/null | tail -n 1 | grep --quiet --fixed-strings -- system; then
    exit
  fi
  MESSAGE="$(jq -e --raw-output '.last_assistant_message' <<< "$JSON")"
  ;;
*)
  set -x
  exit 2
  ;;
esac

if [[ -v TMUX_PANE ]]; then
  LINE="$(tmux display-message -t "$TMUX_PANE" -p '#{pane_title}' | sed -E 's/^[⠀-⣿✱]+[[:space:]]*//')"
else
  LINE="$(basename -- "${CLAUDE_PROJECT_DIR:="$PWD"}")"
fi

TITLE="✻ $LINE"
jq --null-input --arg title "$TITLE" --arg message "$MESSAGE" '{$title, $message}' | "${0%/*}/../libexec/notify.sh"
