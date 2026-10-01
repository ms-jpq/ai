#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${S67_INTERVAL?}"
: "${S67_BACKOFF_INITIAL?}"
: "${S67_BACKOFF_MAX?}"

ONESHOT="${0%/*}/../oneshot/.runner.sh"
BACKOFF="$S67_BACKOFF_INITIAL"

exec 2>&1

while true; do
  if "$ONESHOT" "$@"; then
    DELAY="$S67_INTERVAL"
    BACKOFF="$S67_BACKOFF_INITIAL"
  else
    DELAY="$BACKOFF"
    BACKOFF=$((BACKOFF >= S67_BACKOFF_MAX - BACKOFF ? S67_BACKOFF_MAX : BACKOFF * 2))
  fi
  sleep "$DELAY"
done
