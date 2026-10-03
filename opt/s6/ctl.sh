#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ACTION="$1"
shift -- 1
STATE="$1"

BASE="$(realpath -- "${0%/*}")"
LOGS="$STATE/../log"
TIMEOUT=6000
mkdir -p -- "$STATE" "$LOGS"

case "$ACTION" in
start)
  WS="$(realpath -- "$2")"
  P_PID="${3:-$PPID}"
  P_STARTED="$(LC_ALL=C.UTF-8 ps -p "$P_PID" -o lstart=)"
  DATA="$STATE/watchdog/data"

  "$0" stop "$@"
  env -C "$STATE" -- RECUR=bootstrap "$BASE/jobs/quine/run.sh" quine
  rm -fr -- "$STATE/watchdog"
  env -C "$STATE" -- RECUR=seed "$BASE/jobs/quine/run.sh" watchdog "$P_PID"

  mkdir -p -- "$DATA/launch"
  printf -- '%s' "$P_STARTED" > "$DATA/lstart"
  ln -sTnfr -- "$DATA/lstart" "$DATA/launch/$P_PID"

  S67_WORKING_DIRECTORY="$WS" s6-svscan -- "$STATE" 2>&1 | s6-log -b -l 0 -- T 1 >> "$LOGS/s6.log"
  ;;
stop)
  SCAN="$STATE/.s6-svscan"
  if ! [[ -p $SCAN/control ]]; then
    exit
  fi

  if s6-svscanctl -t -- "$STATE"; then
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
