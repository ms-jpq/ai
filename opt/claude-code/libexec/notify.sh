#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar

SOCK="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.var/claude.notify.sock"

if [[ -t 0 ]]; then
  mkdir -p -- "${SOCK%/*}"
  RECUR=1 socat UNIX-LISTEN:"$SOCK",fork EXEC:"$0"
  exit
fi

JSON="$(tee)"

if [[ -v RECUR ]]; then
  jq . <<< "$JSON" >&2
else
  # shellcheck disable=2154
  "$XDG_CONFIG_HOME/tmux/libexec/taint-inactive.sh"

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

TITLE="$(jq -e --raw-output '.title' <<< "$JSON")"
MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"
exec -- ~/.local/libexec/notify/dispatch.sh "$TITLE" "$MESSAGE"
