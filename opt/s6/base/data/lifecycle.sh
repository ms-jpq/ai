#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

exec 2>&1

INSTANCE_DATA="$PWD/data"
ATTEMPTS="$INSTANCE_DATA/attempt"
PGID_FILE="$INSTANCE_DATA/.pgid"

MODE="${RECUR:-${0##*/}}"
if [[ $MODE == run ]] && [[ $0 -ef ../data/lifecycle.sh ]]; then
  MODE=log
fi

case "$MODE" in
log)
  SERVICE="${PWD%/log}"
  JOB="${SERVICE%/instances/*}"
  exec -- s6-log -b -l 0 -d "$(< ./notification-fd)" -- "p${JOB##*/}@${SERVICE##*/}" 1 >&67
  ;;
run)
  printf -- '%s' "$$" > "$PGID_FILE"
  exec -- s6-envdir -- ./env ./data/lifecycle.sh "$@"
  ;;
lifecycle.sh)
  : "${S9_ON_UNIT_INACTIVE_SEC?}"
  : "${S9_WORKING_DIRECTORY?}"
  : "${S9_RUNTIME_MAX_SEC?}"
  : "${S9_RESTART_SEC?}"
  if ((S9_ON_UNIT_INACTIVE_SEC >= 0)); then
    DELAY="$S9_RESTART_SEC"
    if ((DELAY < S9_ON_UNIT_INACTIVE_SEC)); then
      DELAY="$S9_ON_UNIT_INACTIVE_SEC"
    fi
    : "${S9_RESTART_MAX_DELAY_SEC:=$((DELAY * 2))}"

    if ATTEMPT="$(wc -l 2> /dev/null < "$ATTEMPTS")"; then
      DELAY="$S9_ON_UNIT_INACTIVE_SEC"
      if ((ATTEMPT > 0)); then
        DELAY="$S9_RESTART_SEC"
        if ((DELAY > S9_RESTART_MAX_DELAY_SEC)); then
          DELAY="$S9_RESTART_MAX_DELAY_SEC"
        fi
        while ((--ATTEMPT > 0 && DELAY < S9_RESTART_MAX_DELAY_SEC)); do
          if ((DELAY > S9_RESTART_MAX_DELAY_SEC / 2)); then
            DELAY="$S9_RESTART_MAX_DELAY_SEC"
          else
            DELAY=$((DELAY * 2))
          fi
        done
      fi
      sleep -- "$DELAY"
    fi
  fi

  RECUR=attempt exec -- timeout --foreground --kill-after=5s "$S9_RUNTIME_MAX_SEC" "$0" "$@"
  ;;
attempt)
  unset -- RECUR
  INSTANCE="$1"
  JOB="${PWD%/instances/*}"
  LOGS="$JOB/../../log/${JOB##*/}"

  mkdir -p -- "$LOGS"
  cd -- "$S9_WORKING_DIRECTORY"

  {
    STATUS=0
    nice -n 19 -- "$INSTANCE_DATA/job" "$@" || STATUS=$?
    printf -- '\n'
    exit "$STATUS"
  } 2>&1 | s6-log -b -l 0 -- T "p${JOB##*/}@$INSTANCE" 1 | tee --append -- "$LOGS/$INSTANCE.log" > /dev/null || exit "$?"
  ;;
finish)
  RECUR=finished exec -- s6-envdir -- ./env ./data/lifecycle.sh "$@"
  ;;
finished)
  : "${S9_ON_UNIT_INACTIVE_SEC?}"
  STATUS="$1"
  SIGNAL="$2"
  INSTANCE="$3"
  JOB="${PWD%/instances/*}"
  STATE="$JOB/../.."
  JOB="${JOB##*/}"
  LOG_SRC="$STATE/log/$JOB/$INSTANCE.log"
  TIMESTAMP="$(date -u +%Y%m%dT%H%M%S.%N)"

  if [[ -n ${4:-} ]] || [[ -f $PGID_FILE ]]; then
    PGID="${4:-$(< "$PGID_FILE")}"
    rm -f -- "$PGID_FILE"
    kill -KILL -- "-$PGID" 2> /dev/null || true
  fi

  if ((STATUS == 0 && SIGNAL == 0)); then
    LOG_DST="${S9_DEAD_DIR:-$STATE/dead}/$JOB/$INSTANCE.$TIMESTAMP/log"
  else
    LOG_DST="${S9_DEAD_DIR:-$STATE/failed}/$JOB/$INSTANCE.$TIMESTAMP/log"
  fi
  mkdir -p -- "${LOG_DST%/*}"
  printf -- '%s' "$STATUS" > "${LOG_DST%/*}/exit_status"
  printf -- '%s' "$SIGNAL" > "${LOG_DST%/*}/signal"

  mkdir -p -- "${LOG_SRC%/*}"
  touch -- "$LOG_SRC"
  ln -- "$LOG_SRC" "$LOG_DST"
  rm -fr -- "$LOG_SRC"

  EXIT_STATUS=0
  if ((S9_ON_UNIT_INACTIVE_SEC >= 0)); then
    if ((STATUS == 0 && SIGNAL == 0)); then
      : > "$ATTEMPTS"
    else
      printf -- '\n' >> "$ATTEMPTS"
    fi
  else
    touch -- "../../data/done/$INSTANCE"
    rm -f -- "$INSTANCE_DATA/launch"
    EXIT_STATUS=125
  fi

  tee <<- EOF || exit "$EXIT_STATUS"
------------------------------
status=$STATUS, signal=$SIGNAL
------------------------------
EOF

  exit "$EXIT_STATUS"
  ;;
*)
  set -x
  exit 2
  ;;
esac
