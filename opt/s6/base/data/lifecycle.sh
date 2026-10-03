#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

INSTANCE_DATA="$PWD/data"
ATTEMPTS="$INSTANCE_DATA/attempt"
PGID_FILE="$INSTANCE_DATA/.pgid"

exec 2>&1

case "${0##*/}" in
run)
  printf -- '%s' "$$" > "$PGID_FILE"
  exec -- s6-envdir -- ./env ./data/lifecycle.sh "$@"
  ;;
lifecycle.sh)
  : "${S67_WORKING_DIRECTORY?}"
  : "${S67_RUNTIME_MAX_SEC?}"
  : "${S67_RESTART_SEC?}"
  : "${S67_ON_UNIT_INACTIVE_SEC?}"
  : "${S67_RESTART_MAX_DELAY_SEC:=$((S67_ON_UNIT_INACTIVE_SEC * 2))}"

  if [[ -d $INSTANCE_DATA/launch/recurring ]]; then
    if ATTEMPT="$(wc -l 2> /dev/null < "$ATTEMPTS")"; then
      DELAY="$S67_ON_UNIT_INACTIVE_SEC"
      if ((ATTEMPT > 0)); then
        DELAY="$S67_RESTART_SEC"
        while ((--ATTEMPT > 0 && DELAY < S67_RESTART_MAX_DELAY_SEC)); do
          DELAY=$((DELAY >= S67_RESTART_MAX_DELAY_SEC - DELAY ? S67_RESTART_MAX_DELAY_SEC : DELAY * 2))
        done
      fi
      sleep -- "$DELAY"
    fi
  fi

  cd -- "$S67_WORKING_DIRECTORY"
  exec -- timeout --foreground --kill-after=5s "$S67_RUNTIME_MAX_SEC" nice -n 19 -- "$INSTANCE_DATA/job" "$@"
  ;;
finish)
  STATUS="$1"
  SIGNAL="$2"
  INSTANCE="$3"
  JOB="${PWD%/instances/*}"
  JOB="${JOB##*/}"

  if [[ -n ${4:-} ]] || [[ -f $PGID_FILE ]]; then
    PGID="${4:-$(< "$PGID_FILE")}"
    rm -f -- "$PGID_FILE"
    kill -KILL -- "-$PGID" 2> /dev/null || true
  fi

  EXIT_STATUS=0
  if [[ -d $INSTANCE_DATA/launch/recurring ]]; then
    if ((STATUS == 0 && SIGNAL == 0)); then
      : > "$ATTEMPTS"
    else
      printf -- '\n' >> "$ATTEMPTS"
    fi
  else
    touch -- "../../data/done/$INSTANCE"
    EXIT_STATUS=125
  fi

  tee <<- EOF || exit "$EXIT_STATUS"
------------------------------------------------------------------
Service Stopped :: $JOB@$INSTANCE - status=$STATUS, signal=$SIGNAL
------------------------------------------------------------------
EOF

  exit "$EXIT_STATUS"
  ;;
*)
  set -x
  exit 2
  ;;
esac
