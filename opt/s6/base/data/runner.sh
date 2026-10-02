#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${S67_WORKSPACE?}"
: "${S67_TIMEOUT?}"
: "${S67_BACKOFF_INITIAL?}"
: "${S67_BACKOFF_MAX?}"

exec 2>&1

INSTANCE_DATA="$PWD/data"

if [[ -d $INSTANCE_DATA/recurring ]]; then
  if ATTEMPT="$(wc -l 2> /dev/null < "$INSTANCE_DATA/attempt")"; then
    DELAY="$S67_BACKOFF_INITIAL"
    while ((--ATTEMPT > 0 && DELAY < S67_BACKOFF_MAX)); do
      DELAY=$((DELAY >= S67_BACKOFF_MAX - DELAY ? S67_BACKOFF_MAX : DELAY * 2))
    done
    sleep -- "$DELAY"
  fi
fi

exec -- env -C "$S67_WORKSPACE" -- timeout --foreground --kill-after=5s "$S67_TIMEOUT" nice -n 19 -- "$INSTANCE_DATA/job" "$@"
