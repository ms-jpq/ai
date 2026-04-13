#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar

SELF="$(realpath -- "$0")"
ROOT="${SELF%/*}/../../.."
SOCK="$(realpath -- "$ROOT/var/claude.notify.sock")"

if [[ -t 0 ]]; then
  RECUR=1 socat UNIX-LISTEN:"$SOCK",fork EXEC:"$0"
  exit
fi

JSON="$(tee)"
# "${SELF%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

if jq -e '.notification_type == "idle_prompt"' <<< "$JSON" > /dev/null; then
  exit
fi

if [[ -v RECUR ]]; then
  jq . <<< "$JSON"
else
  ~/.config/tmux/libexec/taint-inactive.sh

  if [[ -v TMUX_PANE ]]; then
    STATUS="$(tmux display-message -t "$TMUX_PANE" -p '#{session_active}#{window_active}')"
    if [[ $STATUS == 11 ]]; then
      exit
    fi
  fi

  if [[ -v SSH_CONNECTION ]]; then
    if [[ -S $SOCK ]]; then
      exec -- socat - "UNIX-CONNECT:$SOCK" <<< "$JSON"
    fi
    exit
  fi
fi

# shellcheck disable=SC2154
FALLBACK="Chatty ~ $(basename -- "${CLAUDE_PROJECT_DIR:="$PWD"}")"
TITLE="$(jq -e --raw-output --arg fallback "$FALLBACK" '.title // $fallback' <<< "$JSON")"
MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"
exec -- ~/.local/libexec/notify.kitty.sh /tmp/kitty.*.sock "$TITLE" "$MESSAGE"
