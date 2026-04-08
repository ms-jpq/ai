#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
ROOT="${SELF%/*}/../../.."
SOCK="$ROOT/var/claude.notify.sock"

if [[ -t 0 ]]; then
  RECUR=1 exec -- socat UNIX-LISTEN:"$SOCK",fork EXEC:"$0"
fi

TEE=(tee --)
if [[ -v RECUR ]]; then
  TEE+=(/dev/stderr)
fi
JSON="$("${TEE[@]}")"

if [[ -v SSH_CONNECTION ]]; then
  if [[ -S $SOCK ]]; then
    exec -- socat - "UNIX-CONNECT:$SOCK" <<< "$JSON"
  fi
  exit
fi

if ! [[ -v RECUR ]]; then
  if [[ -v TMUX_PANE ]] && ! ~/.config/tmux/libexec/pane-active.sh; then
    ~/.config/tmux/libexec/taint-pane.sh
  fi
fi

TITLE="$(jq -e --raw-output '.title // "Claude Code"' <<< "$JSON")"
MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"
exec -- ~/.local/libexec/notify.kitty.sh /tmp/kitty.*.sock "$TITLE" "$MESSAGE"
