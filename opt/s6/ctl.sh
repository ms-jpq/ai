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
  P_PID="${3:-$PPID}"
  P_STARTED="$(LC_ALL=C.UTF-8 ps -p "$P_PID" -o lstart=)"

  "$0" stop "$@"
  env -C "$STATE" -- RECUR=bootstrap "$BASE/jobs/quine/run.sh"
  rm -fr -- "$STATE/watchdog"
  env -C "$STATE" -- RECUR=seed "$BASE/jobs/quine/run.sh" watchdog "$P_PID"

  mkdir -p -- "$STATE/watchdog/data/recurring"
  printf -- '%s' "$P_STARTED" > "$STATE/watchdog/data/$P_PID"
  ln -s -- "../$P_PID" "$STATE/watchdog/data/recurring/$P_PID"

  S67_WORKING_DIRECTORY="$WS" s6-svscan -- "$STATE" 2>&1 | s6-log -b -- T "$LOGS"
  ;;
stop)
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
