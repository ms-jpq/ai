#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

MODE="$1"
shift -- 1
STATE="$1"

LOGS="$STATE/../s6-logs/supervisor"
mkdir -p -- "$STATE" "$LOGS"

case "$MODE" in
compile)
  shopt -u failglob
  BASE="$(realpath -- "${0%/*}/base")"
  RSYNC=(rsync --archive --copy-links --delete)

  "${RSYNC[@]}" --exclude='/.s6-svscan/' -- "$BASE/" "$STATE/"
  for SERVICE in .claude/s6/*/; do
    NAME="${SERVICE%/}"
    NAME="${NAME##*/}"
    "${RSYNC[@]}" -- "$SERVICE" "$STATE/$NAME/"
  done
  ;;
start)
  "$0" shutdown "$@"
  "$0" compile "$@"
  s6-svscan "$STATE" 2>&1 | s6-log -b T "$LOGS"
  ;;
shutdown)
  if ! [[ -p $STATE/.s6-svscan/control ]]; then
    exit
  fi

  if s6-svscanctl -t "$STATE"; then
    s6-setlock "$STATE/.s6-svscan/lock" true
  else
    STATUS=$?
    if ((STATUS != 100)); then
      exit "$STATUS"
    fi
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
