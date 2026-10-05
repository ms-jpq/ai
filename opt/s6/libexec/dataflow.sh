#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

SELF="$(realpath -- "$0")"
ACTION="$1"
shift -- 1
STATE="$(realpath -- "$1")"
shift -- 1
GRAPH="$STATE/graph"
SERVICES="$STATE/services"
mkdir -p -- "$GRAPH"
export LC_ALL=C.UTF-8

case "$ACTION" in
prepare | deliver)
  JOB="$1"
  INSTANCE="$2"
  LIVE="$STATE/live/$JOB/$INSTANCE"
  ;;&
deliver)
  mkdir -p -- "$LIVE" "$STATE/dead/$JOB/$INSTANCE"
  if ! [[ -f $LIVE/.record ]]; then
    RECORD="$STATE/dead/$JOB/$INSTANCE/$(date -u +%Y%m%dT%H%M%S.%N)"
    printf -- '%s' "$3" > "$LIVE/exit_status"
    printf -- '%s' "$4" > "$LIVE/signal"
    printf -- '%s' "${5:-$SERVICES/$JOB/instances/$INSTANCE}" > "$LIVE/.service"
    printf -- '%s' "$RECORD" > "$LIVE/.record-next"
    mv --no-target-directory -- "$LIVE/.record-next" "$LIVE/.record"
  fi
  ;;&
compile | projection | deliver)
  if [[ ${RECUR:-} != dataflow ]]; then
    RECUR=dataflow exec -- s6-setlock -t 6000 -- "$GRAPH/.lock" "$SELF" "$ACTION" "$STATE" "$@"
  fi
  ;;&
prepare)
  if [[ -f $LIVE/.record ]]; then
    "$SELF" deliver "$STATE" "$JOB" "$INSTANCE" > /dev/null
  fi
  mkdir -p -- "$LIVE/outputs" "$LIVE/telemetry"
  if ! [[ -d $LIVE/inputs ]]; then
    if [[ -d $3 ]]; then
      INPUTS="$(RECUR='' "${SELF%/*}/p-cp.sh" "$3" "$LIVE/inputs")"
      mv --no-target-directory -- "$INPUTS" "$LIVE/inputs"
    else
      mkdir -- "$LIVE/inputs"
    fi
  fi
  RECORDS=()
  declare -A -- SEEN=()
  declare -A -- INPUT_ROWS=()
  for INPUT in "$LIVE"/inputs/*; do
    if ! [[ -L $INPUT ]]; then
      continue
    fi
    OUTPUT="$(realpath -- "$INPUT")"
    RECORD="${OUTPUT%/outputs/*}"
    if [[ $RECORD == "$OUTPUT" ]] || ! [[ -f $RECORD/exit_status ]]; then
      continue
    fi
    INPUT_ROWS[$INPUT]="$OUTPUT"
    for PREVIOUS in "$RECORD"/telemetry/* "$RECORD"; do
      PREVIOUS="$(realpath -- "$PREVIOUS")"
      if [[ -z ${SEEN[$PREVIOUS]:-} ]]; then
        SEEN[$PREVIOUS]=1
        RECORDS+=("$PREVIOUS")
      fi
    done
  done
  WIDTH="${#RECORDS[@]}"
  WIDTH="${#WIDTH}"
  NUMBER=0
  for RECORD in "${RECORDS[@]}"; do
    NUMBER=$((NUMBER + 1))
    PARENT="${RECORD%/*}"
    PRODUCER="${PARENT%/*}"
    printf -v LABEL -- '%0*d-%s' "$WIDTH" "$NUMBER" "${PRODUCER##*/}"
    ln -sTnfr -- "$RECORD" "$LIVE/telemetry/$LABEL"
    SEEN[$RECORD]="$LABEL"
  done
  for INPUT in "${!INPUT_ROWS[@]}"; do
    OUTPUT="${INPUT_ROWS[$INPUT]}"
    RECORD="${OUTPUT%/outputs/*}"
    ln -sTnf -- "../telemetry/${SEEN[$RECORD]}/${OUTPUT#"$RECORD"/}" "$INPUT"
  done
  ;;
compile)
  JOBS="$(realpath -- "$1")"
  for RECORD in "$STATE"/live/*/*/.record; do
    LIVE="${RECORD%/*}"
    PRODUCER="${LIVE%/*}"
    "$SELF" deliver "$STATE" "${PRODUCER##*/}" "${LIVE##*/}" > /dev/null
  done
  BUILD="$(mktemp -d -- "$GRAPH/.topology.XXXXXX")"
  trap 'rm -fr -- "$BUILD"' EXIT
  mkdir -- "$BUILD/wants" "$BUILD/wanted-by"
  declare -A -- JOB_NAMES=()
  for JOB in "$JOBS"/*; do
    if [[ -d $JOB ]]; then
      NAME="${JOB##*/}"
      TARGET="$(realpath -- "$JOB")"
      JOB_NAMES[$TARGET]="${JOB_NAMES[$TARGET]:-$NAME}"
      mkdir -p -- "$BUILD/wants/$NAME" "$BUILD/wanted-by/$NAME"
      if [[ -f $SERVICES/$NAME/template/.sum ]]; then
        cp -- "$SERVICES/$NAME/template/.sum" "$BUILD/wants/$NAME/.job.sum"
      fi
    fi
  done
  for JOB in "$BUILD"/wants/*; do
    CONSUMER="${JOB##*/}"
    for WANT in "$SERVICES"/"$CONSUMER"/template/data/wants/*; do
      TARGET="$(realpath -- "$WANT")"
      PRODUCER="${JOB_NAMES[$TARGET]:-}"
      if [[ -z $PRODUCER ]]; then
        printf -- 'Unknown dependency: %s\n' "$WANT" >&2
        exit 2
      fi
      printf -- '%s' "$PRODUCER" > "$BUILD/wants/$CONSUMER/$PRODUCER"
      ln -sTnfr -- "$BUILD/wants/$CONSUMER" "$BUILD/wanted-by/$PRODUCER/$CONSUMER"
    done
  done
  mkdir -- "$BUILD/check"
  for JOB in "$BUILD"/wants/*; do
    "$SELF" visit "$STATE" "$BUILD" "$BUILD/check" "${JOB##*/}" check
  done
  rm -fr -- "$BUILD/check"
  PREVIOUS=''
  if [[ -L $GRAPH/topology ]]; then
    PREVIOUS="$(realpath -- "$GRAPH/topology")"
  fi
  ln -sTnfr -- "$BUILD" "$GRAPH/.topology-next"
  mv --no-target-directory -- "$GRAPH/.topology-next" "$GRAPH/topology"
  trap - EXIT
  if [[ -n $PREVIOUS ]]; then
    rm -fr -- "$PREVIOUS"
  fi
  shift -- 1
  ;&
projection)
  if ! [[ -L $GRAPH/topology ]]; then
    exit
  fi
  TOPOLOGY="$(realpath -- "$GRAPH/topology")"
  PASS="$(mktemp -d -- "$GRAPH/.projection.XXXXXX")"
  trap 'rm -fr -- "$PASS"' EXIT
  mkdir -- "$PASS/.selected"
  if (($#)); then
    PRODUCERS=("$1")
    for ((INDEX = 0; INDEX < ${#PRODUCERS[@]}; INDEX++)); do
      for CONSUMER in "$TOPOLOGY"/wanted-by/"${PRODUCERS[$INDEX]}"/*; do
        CONSUMER="${CONSUMER##*/}"
        if ! [[ -f $PASS/.selected/$CONSUMER ]]; then
          touch -- "$PASS/.selected/$CONSUMER"
          PRODUCERS+=("$CONSUMER")
        fi
      done
    done
  else
    for JOB in "$TOPOLOGY"/wants/*; do
      touch -- "$PASS/.selected/${JOB##*/}"
    done
  fi
  for JOB in "$PASS"/.selected/*; do
    "$SELF" visit "$STATE" "$TOPOLOGY" "$PASS" "${JOB##*/}" projection
  done
  ;;
visit | combine)
  TOPOLOGY="$1"
  PASS="$2"
  JOB="$3"
  shift -- 3
  WANTS=("$TOPOLOGY"/wants/"$JOB"/*)
  ;;&
visit)
  MODE="$1"
  if [[ -f $PASS/$JOB/done ]]; then
    exit
  fi
  if [[ -d $PASS/$JOB ]]; then
    printf -- 'Dependency cycle at %s\n' "$JOB" >&2
    exit 2
  fi
  mkdir -p -- "$PASS/$JOB/records"
  for WANT in "${WANTS[@]}"; do
    "$SELF" visit "$STATE" "$TOPOLOGY" "$PASS" "$(< "$WANT")" "$MODE"
  done
  if [[ $MODE == projection ]] && [[ -f $TOPOLOGY/wants/$JOB/.job.sum ]]; then
    if ((${#WANTS[@]})); then
      "$SELF" combine "$STATE" "$TOPOLOGY" "$PASS" "$JOB"
    else
      for SOURCE in "$STATE"/dead/"$JOB"/*/latest-succ; do
        PARENT="${SOURCE%/*}"
        ln -sTnfr -- "$SOURCE" "$PASS/$JOB/records/${PARENT##*/}"
      done
    fi
  fi
  touch -- "$PASS/$JOB/done"
  ;;
combine)
  INDEX=$(($# / 2))
  if ((INDEX < ${#WANTS[@]})); then
    PRODUCER="$(< "${WANTS[$INDEX]}")"
    for OUTPUT in "$PASS"/"$PRODUCER"/records/*/outputs/*; do
      if ! [[ -d $OUTPUT ]]; then
        continue
      fi
      OUTPUT="$(realpath -- "$OUTPUT")"
      "$SELF" combine "$STATE" "$TOPOLOGY" "$PASS" "$JOB" "$@" "$PRODUCER" "$OUTPUT"
    done
    exit
  fi
  INSTANCE="$(printf -- '%s\0' "$(< "$TOPOLOGY/wants/$JOB/.job.sum")" "${@#"$STATE"/}" | b3sum)"
  INSTANCE="${INSTANCE%% *}"
  if [[ -L $STATE/dead/$JOB/$INSTANCE/latest-succ ]]; then
    ln -sTnfr -- "$STATE/dead/$JOB/$INSTANCE/latest-succ" "$PASS/$JOB/records/$INSTANCE"
  fi
  if ! [[ -f $PASS/.selected/$JOB ]]; then
    exit
  fi
  LAUNCH="$SERVICES/$JOB/data/launch"
  COMPLETED=("$STATE/dead/$JOB/$INSTANCE/"[0-9]*/exit_status)
  if [[ -L $LAUNCH/$INSTANCE ]] || [[ -d $SERVICES/$JOB/instances/$INSTANCE ]] || [[ -f $STATE/live/$JOB/$INSTANCE/.record ]] || ((${#COMPLETED[@]})); then
    exit
  fi
  INPUTS="$GRAPH/cartesian-inputs/$JOB/$INSTANCE"
  mkdir -p -- "$GRAPH/cartesian-inputs/$JOB" "$LAUNCH"
  if ! [[ -d $INPUTS ]]; then
    STAGING="$GRAPH/cartesian-inputs/$JOB/.$INSTANCE"
    rm -fr -- "$STAGING"
    mkdir -- "$STAGING"
    trap 'rm -fr -- "$STAGING"' EXIT
    cp -- "$TOPOLOGY/wants/$JOB/.job.sum" "$STAGING/.job.sum"
    while (($#)); do
      ln -sTnfr -- "$2" "$STAGING/$1"
      shift -- 2
    done
    mv --no-target-directory -- "$STAGING" "$INPUTS"
  fi
  LINK="$(mktemp -- "$LAUNCH/.launch.XXXXXX")"
  trap 'rm -f -- "$LINK"' EXIT
  ln -sTnfr -- "$INPUTS" "$LINK"
  mv --no-target-directory -- "$LINK" "$LAUNCH/$INSTANCE"
  ;;
deliver)
  RECORD="$(< "$LIVE/.record")"
  SERVICE="$(< "$LIVE/.service")"
  if ! [[ -d $RECORD ]]; then
    STAGING="${RECORD%/*}/.${RECORD##*/}"
    rm -fr -- "$STAGING"
    STAGING="$(RECUR='' "${SELF%/*}/p-cp.sh" "$LIVE" "$RECORD")"
    for LINK in "$LIVE/inputs" "$LIVE"/telemetry/*; do
      if [[ -L $LINK ]]; then
        TARGET="$(realpath -- "$LINK")"
        ln -sTnfr -- "$TARGET" "$STAGING/${LINK#"$LIVE"/}"
      fi
    done
    for OUTPUT in "$STAGING/outputs" "$STAGING"/outputs/*; do
      if [[ -d $OUTPUT ]]; then
        if [[ -L $OUTPUT ]]; then
          COPY="$(RECUR='' "${SELF%/*}/p-cp.sh" "$OUTPUT" "$OUTPUT")"
          rm -- "$OUTPUT"
          mv --no-target-directory -- "$COPY" "$OUTPUT"
        fi
        if [[ $OUTPUT != "$STAGING/outputs" ]]; then
          cp --remove-destination -- "$SERVICE/.sum" "$OUTPUT/.job.sum"
        fi
      fi
    done
    rm -- "$STAGING/"{.record,.service}
    mv --no-target-directory -- "$STAGING" "$RECORD"
  fi
  if [[ $(< "$RECORD/exit_status") != 0 ]] || [[ $(< "$RECORD/signal") != 0 ]]; then
    FAILED="$STATE/fail/$JOB/$INSTANCE"
    mkdir -p -- "$FAILED"
    ln -sTnfr -- "$RECORD" "$FAILED/${RECORD##*/}"
    ln -sTnf -- "${RECORD##*/}" "$FAILED/latest"
  fi
  if [[ -f $SERVICE/env/S9_ON_UNIT_INACTIVE_SEC ]] && (($(< "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC") < 0)); then
    touch -- "$SERVICE/../../data/.exited/$INSTANCE"
    rm -f -- "$SERVICE/data/launch"
  fi
  rm -fr -- "$LIVE"
  printf -- '%s\n' "$RECORD"
  ;;
*)
  set -x
  exit 2
  ;;
esac
