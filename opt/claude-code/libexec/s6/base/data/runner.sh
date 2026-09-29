#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${S67_WORKSPACE?}"
: "${S67_INTERVAL?}"
: "${S67_BACKOFF_INITIAL?}"
: "${S67_BACKOFF_MAX?}"

JOB="$PWD/data/job"
BACKOFF="$S67_BACKOFF_INITIAL"

exec 2>&1
printf -- '%s' "$$" > data/pgid

while true; do
  if ./data/reporter.sh nice -n 19 env -C "$S67_WORKSPACE" -- "$JOB"; then
    DELAY="$S67_INTERVAL"
    BACKOFF="$S67_BACKOFF_INITIAL"
  else
    DELAY="$BACKOFF"
    BACKOFF=$((BACKOFF >= S67_BACKOFF_MAX - BACKOFF ? S67_BACKOFF_MAX : BACKOFF * 2))
  fi
  sleep "$DELAY"
done
