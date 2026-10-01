#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${S67_WORKSPACE?}"
: "${S67_TIMEOUT?}"

exec 2>&1

INSTANCE_DATA="$PWD/data"
ATTEMPTS="$INSTANCE_DATA/attempt"

if [[ -f $INSTANCE_DATA/recurring ]]; then
  : "${S67_INTERVAL?}"
  : "${S67_BACKOFF_INITIAL?}"
  : "${S67_BACKOFF_MAX?}"

  DELAY="$S67_INTERVAL"
  if [[ -f $ATTEMPTS ]]; then
    ATTEMPT="$(wc -l < "$ATTEMPTS")"
    DELAY="$S67_BACKOFF_INITIAL"
    for ((I = 1; I < ATTEMPT && DELAY < S67_BACKOFF_MAX; I++)); do
      DELAY=$((DELAY >= S67_BACKOFF_MAX - DELAY ? S67_BACKOFF_MAX : DELAY * 2))
    done
  fi
  sleep "$DELAY"
fi

JOB="$INSTANCE_DATA/job"
exec -- env -C "$S67_WORKSPACE" -- timeout --foreground --kill-after=5s "$S67_TIMEOUT" nice -n 19 -- "$JOB" "$@"
