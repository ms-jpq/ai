#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

ACTION="$1"
shift -- 1
STATE="$1"

BASE="$(realpath -- "${0%/*}")"
LOGS="$STATE/../log/s6.log"
mkdir -p -- "$STATE" "$LOGS"

case "$ACTION" in
start)
  WS="$(realpath -- "$2")"

  "$0" shutdown "$@"
  env -C "$STATE" -- RECUR=0 "$BASE/jobs/quine/run"
  S67_BOOT=1 S67_WORKSPACE="$WS" s6-svscan -- "$STATE" 2>&1 | s6-log -b -- T "$LOGS"
  ;;
shutdown)
  SCAN="$STATE/.s6-svscan"
  if ! [[ -p $SCAN/control ]]; then
    exit
  fi

  if s6-svscanctl -t -- "$STATE"; then
    s6-setlock -- "$SCAN/lock" true
  else
    STATUS=$?
    if ((STATUS != 100)); then
      exit "$STATUS"
    fi
  fi
  ;;
stat)
  for SERVICE in "$STATE/"[!.]*/; do
    printf -- '%s: ' "${SERVICE%/}"
    s6-svstat -- "$SERVICE"
  done
  ;;
*)
  set -x
  exit 2
  ;;
esac
