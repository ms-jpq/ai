#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

ACTION="$1"
shift -- 1
STATE="$1"
SCAN="$STATE/scan"

LOGS="$STATE/../log/s6.log"
mkdir -p -- "$SCAN" "$LOGS"

case "$ACTION" in
start)
  WS="$(realpath -- "$2")"

  "$0" shutdown "$@"
  "${0%/*}/jobs/quine/run" --bootstrap "$STATE"
  S67_WORKSPACE="$WS" s6-svscan "$SCAN" 2>&1 | s6-log -b T "$LOGS"
  ;;
shutdown)
  if ! [[ -p $SCAN/.s6-svscan/control ]]; then
    exit
  fi

  if s6-svscanctl -t "$SCAN"; then
    s6-setlock "$SCAN/.s6-svscan/lock" true
  else
    STATUS=$?
    if ((STATUS != 100)); then
      exit "$STATUS"
    fi
  fi
  ;;
stat)
  for SERVICE in "$SCAN/"[!.]*/; do
    printf -- '%s: ' "${SERVICE%/}"
    s6-svstat "$SERVICE"
  done
  ;;
*)
  set -x
  exit 2
  ;;
esac
