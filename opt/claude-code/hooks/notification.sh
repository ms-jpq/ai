#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
ROOT="${SELF%/*}/../../.."
SOCK="$ROOT/var/claude.notify.sock"

if [[ -t 0 ]]; then
  exec -- socat UNIX-LISTEN:"$SOCK",fork EXEC:"$0"
fi

JSON="$(tee)"

if [[ -v SSH ]]; then
  if [[ -S $SOCK ]]; then
    exec -- socat - "UNIX-CONNECT:$SOCK" <<< "$JSON"
  fi
  exit
fi

TITLE="$(jq -e --raw-output '.title // "Claude Code"' <<< "$JSON")"
MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"
exec -- ~/.local/libexec/notify.kitty.sh /tmp/kitty.*.sock "$TITLE" "$MESSAGE"
