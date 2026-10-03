#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ACTION="$1"
shift -- 1
STATE="$1"

BASE="$(realpath -- "${0%/*}")"
SVCS="$STATE/services"
LOGS="$STATE/log"
TIMEOUT=6000

case "$ACTION" in
start)
  WS="$(realpath -- "$2")"
  P_PID="${3:-$PPID}"
  P_STARTED="$(LC_ALL=C.UTF-8 ps -p "$P_PID" -o lstart=)"
  DATA="$SVCS/watchdog/data"

  "$0" stop "$@"
  rsync --archive --mkpath -- "$BASE/state/" "$STATE/"
  env -C "$SVCS" -- RECUR=bootstrap "$BASE/jobs/quine/run.sh" quine
  rm -fr -- "$SVCS/watchdog"
  env -C "$SVCS" -- RECUR=seed "$BASE/jobs/quine/run.sh" watchdog "$P_PID"

  mkdir -p -- "$DATA/launch"
  printf -- '%s' "$P_STARTED" > "$DATA/lstart"
  ln -sTnfr -- "$DATA/lstart" "$DATA/launch/$P_PID"

  S9_WORKING_DIRECTORY="$WS" s6-svscan -- "$SVCS" 67>&1 2>&1 | s6-log -b -l 0 -- T 1 >> "$LOGS/s6.log"
  ;;
stop)
  SCAN="$SVCS/.s6-svscan"
  if ! [[ -p $SCAN/control ]]; then
    exit
  fi

  if s6-svscanctl -t -- "$SVCS"; then
    s6-setlock -t "$TIMEOUT" -- "$SCAN/lock" true
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
