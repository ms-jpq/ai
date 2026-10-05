#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

ACTION="$1"
shift -- 1
STATE="$(realpath -- "$1")"
shift -- 1
SELF="$(realpath -- "$0")"
GRAPH="$STATE/graph"
mkdir -p -- "$GRAPH"
export LC_ALL=C.UTF-8

if [[ $ACTION == deliver ]]; then
  LIVE="$STATE/live/$1@$2"
  mkdir -p -- "$LIVE" "$GRAPH/pending/$1"
  if ! [[ -f $LIVE/.record ]]; then
    ARCHIVE="$(realpath --canonicalize-missing -- "${5:-$STATE/dead}")"
    printf -- '%s' "$ARCHIVE" > "$LIVE/.archive"
    printf -- '%s' "${6:-$STATE/services/$1/instances/$2}" > "$LIVE/.service"
    printf -- '%s' "$3" > "$LIVE/exit_status"
    printf -- '%s' "$4" > "$LIVE/signal"
    date -u +%Y%m%dT%H%M%S.%N > "$LIVE/.record"
  fi
  ln -sTnfr -- "$LIVE" "$GRAPH/pending/$1/$2"
fi

case "$ACTION" in
compile | project | deliver | index | register)
  if [[ ${RECUR:-} != dataflow ]]; then
    RECUR=dataflow exec -- s6-setlock -t 6000 -- "$GRAPH/.lock" "$SELF" "$ACTION" "$STATE" "$@"
  fi
  ;;
*)
  ;;
esac

case "$ACTION" in
register)
  JOB="$1"
  INSTANCE="$2"
  REQUEST="$3"
  DEFINITION="$4"
  WANTS=("$DEFINITION"/data/wants/*)
  if ((${#WANTS[@]} == 0)) && [[ -L $REQUEST ]] && [[ -d $REQUEST ]]; then
    mkdir -p -- "$GRAPH/sources/$JOB"
    ln -sTnfr -- "$REQUEST" "$GRAPH/sources/$JOB/$INSTANCE"
  fi
  ;;
prepare)
  JOB="$1"
  INSTANCE="$2"
  LIVE="$STATE/live/$JOB@$INSTANCE"
  if [[ -f $LIVE/.record ]]; then
    "$SELF" deliver "$STATE" "$JOB" "$INSTANCE" "$(< "$LIVE/exit_status")" "$(< "$LIVE/signal")"
  fi
  mkdir -p -- "$LIVE/outputs" "$LIVE/telemetry"
  if [[ -d $3 ]]; then
    INPUTS="$(realpath -- "$3")"
    ln -sTnfr -- "$INPUTS" "$LIVE/inputs"
  else
    mkdir -p -- "$LIVE/inputs"
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
  done
  ;;
compile)
  JOBS="$(realpath -- "$1")"
  SERVICES="$(realpath -- "${2:-$STATE/services}")"
  for PENDING in "$GRAPH"/pending/*/*; do
    PRODUCER="${PENDING%/*}"
    if [[ -d $PENDING ]]; then
      "$SELF" deliver "$STATE" "${PRODUCER##*/}" "${PENDING##*/}" "$(< "$PENDING/exit_status")" "$(< "$PENDING/signal")"
    else
      rm -f -- "$PENDING"
    fi
  done
  BUILD="$(mktemp -d -- "$GRAPH/.topology.XXXXXX")"
  trap 'rm -fr -- "$BUILD"' EXIT
  mkdir -- "$BUILD/jobs" "$BUILD/wants" "$BUILD/wanted-by" "$BUILD/definitions"
  ln -sTnfr -- "$SERVICES" "$BUILD/services"
  for JOB in "$JOBS"/*; do
    if [[ -d $JOB ]]; then
      NAME="${JOB##*/}"
      ln -sTnfr -- "$JOB" "$BUILD/jobs/$NAME"
      mkdir -p -- "$BUILD/wants/$NAME" "$BUILD/wanted-by/$NAME"
      if [[ -f $SERVICES/$NAME/template/.sum ]]; then
        cp -- "$SERVICES/$NAME/template/.sum" "$BUILD/definitions/$NAME"
      fi
    fi
  done
  for JOB in "$BUILD"/jobs/*; do
    CONSUMER="${JOB##*/}"
    for REQUEST in "$JOB"/data/launch/* "$SERVICES"/"$CONSUMER"/data/launch/*; do
      "$SELF" register "$STATE" "$CONSUMER" "${REQUEST##*/}" "$REQUEST" "$JOB"
    done
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
      printf -- '%s' "$PRODUCER" > "$BUILD/wants/$CONSUMER/${WANT##*/}"
      ln -sTnfr -- "$JOB" "$BUILD/wanted-by/$PRODUCER/$CONSUMER"
    done
  done
  mkdir -- "$BUILD/check"
  for JOB in "$BUILD"/jobs/*; do
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
  ln -sTnf -- topology/wanted-by "$GRAPH/wanted-by"
  if [[ -n $PREVIOUS ]]; then
    rm -fr -- "$PREVIOUS"
  fi
  "$SELF" project "$STATE"
  ;;
project)
  if ! [[ -L $GRAPH/topology ]]; then
    exit
  fi
  TOPOLOGY="$(realpath -- "$GRAPH/topology")"
  PASS="$(mktemp -d -- "$GRAPH/.projection.XXXXXX")"
  trap 'rm -fr -- "$PASS"' EXIT
  for JOB in "$TOPOLOGY"/jobs/*; do
    "$SELF" visit "$STATE" "$TOPOLOGY" "$PASS" "${JOB##*/}" project
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
  if [[ $MODE == project ]] && [[ -f $TOPOLOGY/definitions/$JOB ]]; then
    if ((${#WANTS[@]})); then
      "$SELF" combine "$STATE" "$TOPOLOGY" "$PASS" "$JOB" 0
    else
      for SOURCE in "$GRAPH"/sources/"$JOB"/*; do
        "$SELF" outputs "$STATE" "$PASS/$JOB/outputs" "$JOB" "${SOURCE##*/}"
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
    HASH="$({
      cat -- "$TOPOLOGY/definitions/$JOB"
      printf -- '%s\0' "$JOB" "${IDENTITIES[@]}"
    } | b3sum)"
    HASH="${HASH%% *}"
    "$SELF" ensure "$STATE" "$TOPOLOGY" "$JOB" "$HASH" "$@"
    "$SELF" outputs "$STATE" "$PASS/$JOB/outputs" "$JOB" "$HASH"
  fi
  ;;
outputs)
  DESTINATION="$1"
  JOB="$2"
  INSTANCE="$3"
  if ! [[ -L $GRAPH/latest/$JOB/$INSTANCE ]]; then
    exit
  fi
  RECORD="$(realpath -- "$GRAPH/latest/$JOB/$INSTANCE")"
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
  SERVICES="$(realpath -- "$TOPOLOGY/services")"
  LAUNCH="$SERVICES/$JOB/data/launch"
  if [[ -L $LAUNCH/$INSTANCE ]] || [[ -d $SERVICES/$JOB/instances/$INSTANCE ]] || [[ -L $GRAPH/completed/$JOB/$INSTANCE ]]; then
    exit
  fi
  INPUTS="$GRAPH/cartesian/$JOB/$INSTANCE"
  mkdir -p -- "$GRAPH/cartesian/$JOB" "$GRAPH/definitions/$JOB" "$LAUNCH"
  if ! [[ -d $INPUTS ]]; then
    STAGING="$(mktemp -d -- "$GRAPH/cartesian/$JOB/.inputs.XXXXXX")"
    trap 'rm -fr -- "$STAGING"' EXIT
    while (($#)); do
      ln -sTnfr -- "$2" "$STAGING/$1"
      shift -- 2
    done
    mv --no-target-directory -- "$STAGING" "$INPUTS"
  fi
  cp -- "$TOPOLOGY/definitions/$JOB" "$GRAPH/definitions/$JOB/$INSTANCE"
  LINK="$(mktemp -- "$LAUNCH/.launch.XXXXXX")"
  trap 'rm -f -- "$LINK"' EXIT
  ln -sTnfr -- "$INPUTS" "$LINK"
  mv --no-target-directory -- "$LINK" "$LAUNCH/$INSTANCE"
  ;;
deliver)
  JOB="$1"
  INSTANCE="$2"
  LIVE="$STATE/live/$JOB@$INSTANCE"
  if ! [[ -f $LIVE/.record ]] && [[ -L $GRAPH/completed/$JOB/$INSTANCE ]]; then
    exit
  fi
  DEAD="$(< "$LIVE/.archive")"
  SERVICE="$(< "$LIVE/.service")"
  mkdir -p -- "$LIVE" "$DEAD/$JOB"
  DEAD="$(realpath -- "$DEAD")"
  RECORD="$DEAD/$JOB/$INSTANCE.$(< "$LIVE/.record")"
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
    rm -- "$STAGING/"{.record,.archive,.service}
    mv --no-target-directory -- "$STAGING" "$RECORD"
  fi
  "$SELF" index "$STATE" "$JOB" "$INSTANCE" "$RECORD"
  if [[ -f $SERVICE/env/S9_ON_UNIT_INACTIVE_SEC ]] && (($(< "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC") < 0)); then
    touch -- "$SERVICE/../../data/done/$INSTANCE"
    rm -f -- "$SERVICE/data/launch"
  fi
  rm -fr -- "$LIVE"
  rm -f -- "$GRAPH/pending/$JOB/$INSTANCE"
  if "$SELF" project "$STATE"; then
    :
  else
    printf -- 'Dataflow projection deferred after publishing %s\n' "$RECORD" >&2
  fi
  ;;
index)
  JOB="$1"
  INSTANCE="$2"
  RECORD="$(realpath -- "$3")"
  mkdir -p -- "$GRAPH/completed/$JOB"
  LINK="$(mktemp -- "$GRAPH/completed/$JOB/.completed.XXXXXX")"
  trap 'rm -f -- "$LINK"' EXIT
  ln -sTnfr -- "$RECORD" "$LINK"
  mv --no-target-directory -- "$LINK" "$GRAPH/completed/$JOB/$INSTANCE"
  if [[ $(< "$RECORD/exit_status") == 0 ]] && [[ $(< "$RECORD/signal") == 0 ]]; then
    INDEX="$GRAPH/latest/$JOB"
    mkdir -p -- "$INDEX"
    if [[ -L $INDEX/$INSTANCE ]]; then
      PREVIOUS="$(realpath -- "$INDEX/$INSTANCE")"
      if [[ ${PREVIOUS##*/} > ${RECORD##*/} ]]; then
        exit
      fi
    fi
    LINK="$(mktemp -- "$INDEX/.latest.XXXXXX")"
    trap 'rm -f -- "$LINK"' EXIT
    ln -sTnfr -- "$RECORD" "$LINK"
    mv --no-target-directory -- "$LINK" "$INDEX/$INSTANCE"
  else
    mkdir -p -- "$STATE/failed/$JOB"
    ln -sTnfr -- "$RECORD" "$STATE/failed/$JOB/${RECORD##*/}"
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
