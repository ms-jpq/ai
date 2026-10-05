#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

ACTION="$1"
shift -- 1
STATE="$(realpath -- "$1")"
shift -- 1
SELF="$(realpath -- "$0")"
GRAPH="$STATE/graph"
SERVICES="$STATE/services"
mkdir -p -- "$GRAPH"
export LC_ALL=C.UTF-8

if [[ $ACTION == deliver ]]; then
  LIVE="$STATE/live/$1@$2"
  mkdir -p -- "$LIVE" "$STATE/dead/$1"
  if ! [[ -f $LIVE/.record ]]; then
    mkdir -p -- "${5:-$STATE/dead}/$1"
    RECORD="$(realpath -- "${5:-$STATE/dead}/$1")"
    RECORD="$RECORD/$2.$(date -u +%Y%m%dT%H%M%S.%N)"
    printf -- '%s' "$3" > "$LIVE/exit_status"
    printf -- '%s' "$4" > "$LIVE/signal"
    printf -- '%s' "${6:-$STATE/services/$1/instances/$2}" > "$LIVE/.service"
    printf -- '%s' "$RECORD" > "$LIVE/.record-next"
    mv --no-target-directory -- "$LIVE/.record-next" "$LIVE/.record"
  fi
fi

case "$ACTION" in
compile | projection | deliver)
  if [[ ${RECUR:-} != dataflow ]]; then
    RECUR=dataflow exec -- s6-setlock -t 6000 -- "$GRAPH/.lock" "$SELF" "$ACTION" "$STATE" "$@"
  fi
  ;;
*)
  ;;
esac

case "$ACTION" in
prepare)
  JOB="$1"
  INSTANCE="$2"
  LIVE="$STATE/live/$JOB@$INSTANCE"
  if [[ -f $LIVE/.record ]]; then
    "$SELF" deliver "$STATE" "$JOB" "$INSTANCE" "$(< "$LIVE/exit_status")" "$(< "$LIVE/signal")"
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
  for INPUT in "$LIVE"/inputs/*; do
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
    PRODUCER="${RECORD%/*}"
    ATTEMPT="${RECORD##*/}"
    printf -v LABEL -- '%0*d-%s@%s' "$WIDTH" "$NUMBER" "${PRODUCER##*/}" "${ATTEMPT%%.*}"
    ln -sTnfr -- "$RECORD" "$LIVE/telemetry/$LABEL"
    SEEN[$RECORD]="$LABEL"
  done
  for INPUT in "$LIVE"/inputs/*; do
    if [[ -L $INPUT ]]; then
      OUTPUT="$(realpath -- "$INPUT")"
      RECORD="${OUTPUT%/outputs/*}"
      if [[ -n ${SEEN[$RECORD]:-} ]]; then
        ln -sTnf -- "../telemetry/${SEEN[$RECORD]}/${OUTPUT#"$RECORD"/}" "$INPUT"
      fi
    fi
  done
  ;;
compile)
  JOBS="$(realpath -- "$1")"
  for RECORD in "$STATE"/live/*/.record; do
    LIVE="${RECORD%/*}"
    SERVICE="$(< "$LIVE/.service")"
    PRODUCER="${SERVICE%/instances/*}"
    "$SELF" deliver "$STATE" "${PRODUCER##*/}" "${SERVICE##*/}" "$(< "$LIVE/exit_status")" "$(< "$LIVE/signal")"
  done
  BUILD="$(mktemp -d -- "$GRAPH/.topology.XXXXXX")"
  trap 'rm -fr -- "$BUILD"' EXIT
  mkdir -- "$BUILD/jobs" "$BUILD/wants" "$BUILD/wanted-by"
  for JOB in "$JOBS"/*; do
    if [[ -d $JOB ]]; then
      NAME="${JOB##*/}"
      ln -sTnfr -- "$JOB" "$BUILD/jobs/$NAME"
      mkdir -p -- "$BUILD/wants/$NAME" "$BUILD/wanted-by/$NAME"
      if [[ -f $SERVICES/$NAME/template/.sum ]]; then
        cp -- "$SERVICES/$NAME/template/.sum" "$BUILD/wants/$NAME/.job.sum"
      fi
    fi
  done
  for JOB in "$BUILD"/jobs/*; do
    CONSUMER="${JOB##*/}"
    for WANT in "$SERVICES"/"$CONSUMER"/template/data/wants/*; do
      PRODUCER=''
      for CANDIDATE in "$BUILD"/jobs/*; do
        if [[ $WANT -ef $CANDIDATE ]]; then
          PRODUCER="${CANDIDATE##*/}"
          break
        fi
      done
      if [[ -z $PRODUCER ]]; then
        printf -- 'Unknown dependency: %s\n' "$WANT" >&2
        exit 2
      fi
      printf -- '%s' "$PRODUCER" > "$BUILD/wants/$CONSUMER/$PRODUCER"
      ln -sTnfr -- "$BUILD/wants/$CONSUMER" "$BUILD/wanted-by/$PRODUCER/$CONSUMER"
    done
  done
  mkdir -- "$BUILD/check"
  for JOB in "$BUILD"/jobs/*; do
    "$SELF" visit "$STATE" "$BUILD" "$BUILD/check" "${JOB##*/}" check
  done
  rm -fr -- "$BUILD/check" "$BUILD/jobs"
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
  "$SELF" projection "$STATE"
  ;;
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
visit)
  TOPOLOGY="$1"
  PASS="$2"
  JOB="$3"
  MODE="$4"
  if [[ -f $PASS/$JOB/done ]]; then
    exit
  fi
  if [[ -d $PASS/$JOB ]]; then
    printf -- 'Dependency cycle at %s\n' "$JOB" >&2
    exit 2
  fi
  mkdir -p -- "$PASS/$JOB/outputs"
  WANTS=("$TOPOLOGY"/wants/"$JOB"/*)
  for WANT in "${WANTS[@]}"; do
    "$SELF" visit "$STATE" "$TOPOLOGY" "$PASS" "$(< "$WANT")" "$MODE"
  done
  if [[ $MODE == projection ]] && [[ -f $TOPOLOGY/wants/$JOB/.job.sum ]]; then
    if ((${#WANTS[@]})); then
      "$SELF" combine "$STATE" "$TOPOLOGY" "$PASS" "$JOB" 0
    else
      for SOURCE in "$STATE"/dead/"$JOB"/*.latest-succ; do
        INSTANCE="${SOURCE##*/}"
        "$SELF" outputs "$STATE" "$PASS/$JOB/outputs" "$JOB" "${INSTANCE%.latest-succ}"
      done
    fi
  fi
  touch -- "$PASS/$JOB/done"
  ;;
combine)
  TOPOLOGY="$1"
  PASS="$2"
  JOB="$3"
  INDEX="$4"
  shift -- 4
  WANTS=("$TOPOLOGY"/wants/"$JOB"/*)
  if ((INDEX < ${#WANTS[@]})); then
    PRODUCER="$(< "${WANTS[$INDEX]}")"
    for OUTPUT in "$PASS"/"$PRODUCER"/outputs/*; do
      OUTPUT="$(realpath -- "$OUTPUT")"
      "$SELF" combine "$STATE" "$TOPOLOGY" "$PASS" "$JOB" "$((INDEX + 1))" "$@" "${WANTS[$INDEX]##*/}" "$OUTPUT"
    done
  else
    IDENTITIES=()
    for IDENTITY in "$@"; do
      IDENTITIES+=("${IDENTITY#"$STATE"/}")
    done
    HASH="$(printf -- '%s\0' "$(< "$TOPOLOGY/wants/$JOB/.job.sum")" "${IDENTITIES[@]}" | b3sum)"
    HASH="${HASH%% *}"
    if [[ -f $PASS/.selected/$JOB ]]; then
      "$SELF" ensure "$STATE" "$TOPOLOGY" "$JOB" "$HASH" "$@"
    fi
    "$SELF" outputs "$STATE" "$PASS/$JOB/outputs" "$JOB" "$HASH"
  fi
  ;;
outputs)
  DESTINATION="$1"
  JOB="$2"
  INSTANCE="$3"
  if ! [[ -L $STATE/dead/$JOB/$INSTANCE.latest-succ ]]; then
    exit
  fi
  RECORD="$(realpath -- "$STATE/dead/$JOB/$INSTANCE.latest-succ")"
  for OUTPUT in "$RECORD"/outputs/*; do
    if [[ -d $OUTPUT ]]; then
      HASH="$(printf -- '%s\0' "${OUTPUT#"$STATE"/}" | b3sum)"
      ln -sTnfr -- "$OUTPUT" "$DESTINATION/${HASH%% *}"
    fi
  done
  ;;
ensure)
  TOPOLOGY="$1"
  JOB="$2"
  INSTANCE="$3"
  shift -- 3
  LAUNCH="$SERVICES/$JOB/data/launch"
  if [[ -L $LAUNCH/$INSTANCE ]] || [[ -d $SERVICES/$JOB/instances/$INSTANCE ]] || [[ -f $STATE/live/$JOB@$INSTANCE/.record ]] || [[ -L $GRAPH/indices/dead/$JOB/$INSTANCE ]]; then
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
  JOB="$1"
  INSTANCE="$2"
  LIVE="$STATE/live/$JOB@$INSTANCE"
  if ! [[ -f $LIVE/.record ]] && [[ -L $GRAPH/indices/dead/$JOB/$INSTANCE ]]; then
    exit
  fi
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
  mkdir -p -- "$GRAPH/indices/dead/$JOB"
  LINK="$(mktemp -- "$GRAPH/indices/dead/$JOB/.dead.XXXXXX")"
  trap 'rm -f -- "$LINK"' EXIT
  ln -sTnfr -- "$RECORD" "$LINK"
  mv --no-target-directory -- "$LINK" "$GRAPH/indices/dead/$JOB/$INSTANCE"
  if [[ $(< "$RECORD/exit_status") != 0 ]] || [[ $(< "$RECORD/signal") != 0 ]]; then
    mkdir -p -- "$STATE/failed/$JOB"
    ln -sTnfr -- "$RECORD" "$STATE/failed/$JOB/${RECORD##*/}"
  fi
  if [[ -f $SERVICE/env/S9_ON_UNIT_INACTIVE_SEC ]] && (($(< "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC") < 0)); then
    touch -- "$SERVICE/../../data/.exited/$INSTANCE"
    rm -f -- "$SERVICE/data/launch"
  fi
  rm -fr -- "$LIVE"
  ;;
*)
  set -x
  exit 2
  ;;
esac
