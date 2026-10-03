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

LOGGER=(s6-log -b -l 0)
LOG_FMT=("p$JOB@${INSTANCE_DIR##*/}" 1)

case "$MODE" in
log)
  exec -- "${LOGGER[@]}" -d "$(< ./notification-fd)" -- "${LOG_FMT[@]}" >&67
  ;;
run)
  printf -- '%s' "$$" > "$PGID_FILE"
  ;;&
finish)
  export -- RECUR=finished
  ;;&
run | finish)
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
  LOGS="$JOB_DIR/../../log/$JOB"

  mkdir -p -- "$LOGS"
  cd -- "$S9_WORKING_DIRECTORY"

  {
    STATUS=0
    nice -n 19 -- "$INSTANCE_DATA/job" "$@" || STATUS=$?
    printf -- '\n'
    exit "$STATUS"
  } 2>&1 | "${LOGGER[@]}" -- T "${LOG_FMT[@]}" | tee --append -- "$LOGS/$INSTANCE.log" > /dev/null || exit "$?"
  ;;
finished)
  : "${S9_ON_UNIT_INACTIVE_SEC?}"
  STATUS="$1"
  SIGNAL="$2"
  INSTANCE="$3"
  read -r -d '' EXIT_LINES <<- EOF || true
--- exit_status=$STATUS signal=$SIGNAL ---
EOF
  STATE="$JOB_DIR/../.."
  LOG_SRC="$STATE/log/$JOB/$INSTANCE.log"

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
    touch -- "../../data/done/$INSTANCE"
    rm -f -- "$INSTANCE_DATA/launch"
    EXIT_STATUS=125
  fi

  TIMESTAMP="$(date -u +%Y%m%dT%H%M%S.%N)"
  : "${S9_DEAD_DIR:=$STATE/dead}"
  LOG_DST="$S9_DEAD_DIR/$JOB/$INSTANCE.$TIMESTAMP/log"
  mkdir -p -- "$S9_DEAD_DIR/$JOB"

  STAGING="$(mktemp -d -- "$S9_DEAD_DIR/$JOB/.$INSTANCE.XXXXXX")"
  trap 'rm -fr -- "$STAGING"' EXIT
  printf -- '%s' "$STATUS" > "$STAGING/exit_status"
  printf -- '%s' "$SIGNAL" > "$STAGING/signal"

  mkdir -p -- "${LOG_SRC%/*}"
  "${LOGGER[@]}" -- T "${LOG_FMT[@]}" <<< "$EXIT_LINES" | tee --append -- "$LOG_SRC" > /dev/null
  ln -- "$LOG_SRC" "$STAGING/log"
  mv --no-target-directory -- "$STAGING" "${LOG_DST%/*}"
  if ((STATUS != 0 || SIGNAL != 0)); then
    mkdir -p -- "$STATE/failed/$JOB"
    ln -sTnfr -- "${LOG_DST%/*}" "$STATE/failed/$JOB/$INSTANCE.$TIMESTAMP"
  fi
  rm -fr -- "$LOG_SRC"

  printf -- '%s\n' "$EXIT_LINES"
  exit "$EXIT_STATUS"
  ;;
*)
  set -x
  exit 2
  ;;
esac
