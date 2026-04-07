#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if [[ -t 0 ]]; then
  ROOT="${0%/*}/.."
  exec -- socat UNIX-LISTEN:"$ROOT/var/claude.notify.sock",fork EXEC:"$0"
fi

JSON="$(tee)"

# shellcheck disable=SC2154
NOTIFY_SOCK="$XDG_RUNTIME_DIR/claude.notify.sock"

if [[ -v SSH ]]; then
  if [[ -S $NOTIFY_SOCK ]]; then
    exec -- socat - "UNIX-CONNECT:$NOTIFY_SOCK" <<< "$JSON"
  fi
  exit
fi

TITLE="$(jq -e --raw-output '.title // "Claude Code"' <<< "$JSON")"
MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"
exec -- ~/.local/libexec/notify.kitty.sh /tmp/kitty.*.sock "$TITLE" "$MESSAGE"
