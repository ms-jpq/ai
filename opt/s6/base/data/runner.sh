#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${S67_WORKING_DIRECTORY?}"
: "${S67_RUNTIME_MAX_SEC?}"
: "${S67_RESTART_SEC?}"
: "${S67_RESTART_MAX_DELAY_SEC:=$((S67_ON_UNIT_INACTIVE_SEC * 2))}"

exec 2>&1

INSTANCE_DATA="$PWD/data"

if [[ -d $INSTANCE_DATA/recurring ]]; then
  if ATTEMPT="$(wc -l 2> /dev/null < "$INSTANCE_DATA/attempt")"; then
    DELAY="$S67_RESTART_SEC"
    while ((--ATTEMPT > 0 && DELAY < S67_RESTART_MAX_DELAY_SEC)); do
      DELAY=$((DELAY >= S67_RESTART_MAX_DELAY_SEC - DELAY ? S67_RESTART_MAX_DELAY_SEC : DELAY * 2))
    done
    sleep -- "$DELAY"
  fi
fi

exec -- env -C "$S67_WORKING_DIRECTORY" -- timeout --foreground --kill-after=5s "$S67_RUNTIME_MAX_SEC" nice -n 19 -- "$INSTANCE_DATA/job" "$@"
