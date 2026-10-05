#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

exec 2>&1

INSTANCE_DATA="$PWD/data"
ATTEMPTS="$INSTANCE_DATA/attempt"
PGID_FILE="$INSTANCE_DATA/.pgid"

MODE="${RECUR:-${0##*/}}"
INSTANCE_DIR="$PWD"
if [[ $MODE == run ]] && [[ $0 -ef ../data/lifecycle.sh ]]; then
  MODE=log
  INSTANCE_DIR="${PWD%/log}"
fi
JOB_DIR="${INSTANCE_DIR%/instances/*}"
JOB="${JOB_DIR##*/}"
STATE="$JOB_DIR/../.."
LIVE="$STATE/live/$JOB@${INSTANCE_DIR##*/}"

LOGGER=(s6-log -b -l 0)
LOG_FMT=("p$JOB@${INSTANCE_DIR##*/}" 1)

case "$MODE" in
log)
  exec -- "${LOGGER[@]}" -d "$(< ./notification-fd)" -- "${LOG_FMT[@]}" >&67
  ;;
run)
  printf -- '%s' "$$" > "$PGID_FILE"
  export -- RECUR=running
  ;;&
finish)
  export -- RECUR=finished
  ;;&
run | finish)
  exec -- s6-envdir -- ./env "$0" "$@"
  ;;
running)
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

  RECUR=attempt exec -- timeout --foreground --kill-after=5s "$S9_RUNTIME_MAX_SEC" nice -n 19 -- "$0" "$@"
  ;;
attempt)
  unset -- RECUR
  INSTANCE="$1"
  "$INSTANCE_DATA/dataflow.sh" prepare "$STATE" "$JOB" "$INSTANCE" "$INSTANCE_DATA/launch"
  cd -- "$S9_WORKING_DIRECTORY"

  {
    STATUS=0
    tee <<- EOF
--- started ---
EOF
    "$INSTANCE_DATA/job" "$@" || STATUS=$?
    printf -- '\n'
    exit "$STATUS"
  } 2>&1 | "${LOGGER[@]}" -- T "${LOG_FMT[@]}" | tee --append -- "$LIVE/log" > /dev/null || exit "$?"
  ;;
finished)
  : "${S9_ON_UNIT_INACTIVE_SEC?}"
  STATUS="$1"
  SIGNAL="$2"
  INSTANCE="$3"
  LOG_SRC="$LIVE/log"
  IFS= read -r -d '' EXIT_LINES <<- EOF || true
--- exit_status=$STATUS signal=$SIGNAL ---
EOF

  if [[ -n ${4:-} ]] || [[ -f $PGID_FILE ]]; then
    PGID="${4:-$(< "$PGID_FILE")}"
    rm -f -- "$PGID_FILE"
    kill -KILL -- "-$PGID" 2> /dev/null || true
  fi

  EXIT_STATUS=0
  if ((S9_ON_UNIT_INACTIVE_SEC >= 0)); then
    if ((STATUS == 0 && SIGNAL == 0)); then
      : > "$ATTEMPTS"
    else
      printf -- '\n' >> "$ATTEMPTS"
    fi
  else
    EXIT_STATUS=125
  fi

  : "${S9_DEAD_DIR:=$STATE/dead}"
  mkdir -p -- "${LOG_SRC%/*}"
  "${LOGGER[@]}" -- T "${LOG_FMT[@]}" <<< "$EXIT_LINES" | tee --append -- "$LOG_SRC" > /dev/null
  "$INSTANCE_DATA/dataflow.sh" deliver "$STATE" "$JOB" "$INSTANCE" "$STATUS" "$SIGNAL" "$S9_DEAD_DIR" "$INSTANCE_DIR"
  if ((EXIT_STATUS == 125)); then
    touch -- "../../data/done/$INSTANCE"
    rm -f -- "$INSTANCE_DATA/launch"
  fi
  printf -- '%s' "$EXIT_LINES"
  exit "$EXIT_STATUS"
  ;;
*)
  set -x
  exit 2
  ;;
esac
