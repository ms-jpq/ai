#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

MODE="$1"
STATE="$2"

mkdir -p -- "$STATE"
if [[ -p $STATE/.s6-svscan/control ]]; then
  if s6-svscanctl -t "$STATE"; then
    s6-setlock "$STATE/.s6-svscan/lock" true
  else
    STATUS=$?
    if ((STATUS != 100)); then
      exit "$STATUS"
    fi
  fi
fi

case "$MODE" in
start)
  exec -- s6-svscan "$STATE"
  ;;
shutdown)
  ;;
*)
  set -x
  exit 2
  ;;
esac
