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

if [[ -v SSH ]]; then
  if [[ -S $SOCK ]]; then
    exec -- socat - "UNIX-CONNECT:$SOCK" <<< "$JSON"
  fi
  exit
fi

EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
case "$EVENT" in
# PermissionRequest)
#   TITLE="PermissionRequest: $(jq -e --raw-output '.tool_name' <<< "$JSON")"
#   MESSAGE="$(jq -e --raw-output '.tool_input' <<< "$JSON")"
#   ;;
Notification)
  TITLE="$(jq -e --raw-output '.title // "Claude Code"' <<< "$JSON")"
  MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"
  ;;
*)
  set -x
  exit 2
  ;;
esac

exec -- ~/.local/libexec/notify.kitty.sh /tmp/kitty.*.sock "$TITLE" "$MESSAGE"
