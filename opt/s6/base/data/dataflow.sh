#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

: "${S9_GRAPH_TIMEOUT?}"

SELF="$0"
ACTION="$1"
STATE="$(realpath -- "$2")"
JOB="$3"
INSTANCE="$4"
shift -- 4

GRAPH="$STATE/graph"
SERVICES="$STATE/services"
LIVE="$STATE/live/$JOB/$INSTANCE"
INPUTS="$LIVE/inputs"
TELEMETRY="$LIVE/telemetry"
DEAD="$STATE/dead/$JOB/$INSTANCE"
RECORD_FILE="$LIVE/.s9/record"
PCP="${SELF%/*}/p-cp.sh"
mkdir -p -- "$GRAPH"

case "$ACTION" in
prepare)
  if [[ -f $RECORD_FILE ]]; then
    "$SELF" deliver "$STATE" "$JOB" "$INSTANCE"
  fi

  mkdir -p -- "$LIVE/outputs" "$TELEMETRY"
  if ! [[ -d $INPUTS ]] && [[ -d $1 ]]; then
    COPY="$(RECUR='' "$PCP" "$1" "$INPUTS")"
    mv --no-target-directory -- "$COPY" "$INPUTS"
  fi
  mkdir -p -- "$INPUTS"

  for INPUT in "$INPUTS"/*; do
    if ! [[ -L $INPUT ]]; then
      continue
    fi

    OUTPUT="$(realpath -- "$INPUT")"
    RECORD="${OUTPUT%/outputs/*}"
    if [[ $RECORD == "$OUTPUT" ]] || ! [[ -f $RECORD/exit_status ]]; then
      continue
    fi

    for PREVIOUS in "$RECORD"/telemetry/* "$RECORD"; do
      PREVIOUS="$(realpath -- "$PREVIOUS")"
      PARENT="${PREVIOUS%/*}"
      PRODUCER="${PARENT%/*}"
      LABEL="${PRODUCER##*/}@${PARENT##*/}.${PREVIOUS##*/}"
      ln -sTnfr -- "$PREVIOUS" "$TELEMETRY/$LABEL"
    done
    ln -sTnf -- "../telemetry/$LABEL/${OUTPUT#"$RECORD"/}" "$INPUT"
  done
  ;;
deliver)
  if [[ ${RECUR:-} != dataflow ]]; then
    if (($#)) && ! [[ -f $RECORD_FILE ]]; then
      mkdir -p -- "$LIVE/.s9"
      RECORD="$DEAD/$(date -u +%Y%m%dT%H%M%S.%N)"
      printf -- '%s' "$1" > "$LIVE/exit_status"
      printf -- '%s' "$2" > "$LIVE/signal"
      printf -- '%s' "$RECORD" > "$RECORD_FILE-next"
      mv --no-target-directory -- "$RECORD_FILE-next" "$RECORD_FILE"
    fi
    RECUR=dataflow exec -- s6-setlock -t "$((S9_GRAPH_TIMEOUT * 1000))" -- "$GRAPH/.lock" "$SELF" "$ACTION" "$STATE" "$JOB" "$INSTANCE"
  fi
  if ! [[ -f $RECORD_FILE ]]; then
    exit
  fi

  mkdir -p -- "$DEAD"
  RECORD="$(< "$RECORD_FILE")"
  SERVICE="$SERVICES/$JOB/instances/$INSTANCE"
  if ! [[ -d $RECORD ]]; then
    STAGING="${RECORD%/*}/.${RECORD##*/}"
    rm -fr -- "$STAGING"
    STAGING="$(RECUR='' "$PCP" "$LIVE" "$RECORD")"
    for LINK in "$TELEMETRY"/*; do
      ln -sTnfr -- "$LINK" "$STAGING/telemetry/${LINK##*/}"
    done

    for OUTPUT in "$STAGING/outputs" "$STAGING"/outputs/*; do
      if ! [[ -d $OUTPUT ]]; then
        continue
      fi

      if [[ -L $OUTPUT ]]; then
        COPY="$(RECUR='' "$PCP" "$OUTPUT" "$OUTPUT")"
        rm -- "$OUTPUT"
        mv --no-target-directory -- "$COPY" "$OUTPUT"
      fi

      if [[ $OUTPUT != "$STAGING/outputs" ]]; then
        mkdir -p -- "$OUTPUT/.s9"
        cp --remove-destination -- "$SERVICE/data/.s9/defs.sum" "$OUTPUT/.s9/defs.sum"
      fi
    done
    rm -- "$STAGING/.s9/record"
    mv --no-target-directory -- "$STAGING" "$RECORD"
  fi

  SUCCESS=0
  if [[ $(< "$RECORD/exit_status") == 0 ]] && [[ $(< "$RECORD/signal") == 0 ]]; then
    ln -sTnfr -- "$RECORD" "$DEAD/latest-succ"
    SUCCESS=1
  else
    FAILED="$STATE/fail/$JOB/$INSTANCE"
    mkdir -p -- "$FAILED"
    ln -sTnfr -- "$RECORD" "$FAILED/${RECORD##*/}"
    ln -sTnf -- "${RECORD##*/}" "$FAILED/latest"
  fi

  if [[ -f $SERVICE/env/S9_ON_UNIT_INACTIVE_SEC ]] && (($(< "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC") < 0)); then
    ln -sTnfr -- "$RECORD" "$SERVICE/data/.s9/died"
    rm -f -- "$SERVICE/data/launch"
  fi

  rm -fr -- "$LIVE"
  if ((SUCCESS)) && ! "${SELF%/*}/topology.sh" projection "$STATE" "$JOB"; then
    printf -- 'Dataflow projection deferred: %s@%s\n' "$JOB" "$INSTANCE" >&2
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
