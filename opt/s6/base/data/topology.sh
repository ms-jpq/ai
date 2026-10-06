#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

: "${S9_GRAPH_TIMEOUT?}"

SELF="$0"
ACTION="$1"
STATE="$2"
shift -- 2

if [[ $ACTION == compile ]] || [[ $ACTION == projection ]]; then
  SELF="$(realpath -- "$SELF")"
  STATE="$(realpath -- "$STATE")"
fi

GRAPH="$STATE/graph"
SERVICES="$STATE/services"
TOPOLOGY="$GRAPH/topology"
INPUTS_ROOT="$GRAPH/inputs"
DEAD="$STATE/dead"
XARGS=(xargs --null --no-run-if-empty --max-procs=0 --max-args=1 --)
TRAVERSAL="${SELF%/*}/traversal.sh"

case "$ACTION" in
compile | projection)
  mkdir -p -- "$SERVICES"
  if [[ ${RECUR:-} != reconcile ]]; then
    RECUR=reconcile exec -- s6-setlock -t "$((S9_GRAPH_TIMEOUT * 1000))" -- "$SERVICES/.reconcile.lock" "$SELF" "$ACTION" "$STATE" "$@"
  fi
  mkdir -p -- "$GRAPH"
  ;;&
compile)
  for RECORD in "$STATE"/live/*/*/.s9/record; do
    printf -- '%s\0' "$RECORD"
  done | "${XARGS[@]}" "$SELF" recover "$STATE"

  DEFINITIONS=()
  for JOB in "$1"/*; do
    NAME="${JOB##*/}"
    SOURCE="$SERVICES/$NAME/template/data/.s9/source"
    if ! [[ -d $JOB ]] || ! [[ -L $SOURCE ]]; then
      continue
    fi
    TARGET="$(readlink -- "$SOURCE")"
    DEFINITION=''
    if [[ -f $SERVICES/$NAME/template/data/.s9/defs.sum ]]; then
      DEFINITION="$(< "$SERVICES/$NAME/template/data/.s9/defs.sum")"
    fi
    DEFINITIONS+=("$NAME" "$TARGET" "$DEFINITION")
  done
  INPUT_SUM="$(printf -- '%s\0' "${DEFINITIONS[@]}" | b3sum)"
  if [[ -f $TOPOLOGY/.s9/inputs.sum ]] && [[ $(< "$TOPOLOGY/.s9/inputs.sum") == "$INPUT_SUM" ]]; then
    exec -- "$SELF" projection "$STATE"
  fi
  BUILD="$(mktemp -d -- "$GRAPH/.topology.XXXXXX")"
  trap 'rm -fr -- "$BUILD"' EXIT
  DIRECTORIES=("$BUILD/wants" "$BUILD/.s9")
  for ((INDEX = 0; INDEX < ${#DEFINITIONS[@]}; INDEX += 3)); do
    DIRECTORIES+=("$BUILD/wants/${DEFINITIONS[$INDEX]}/.s9")
  done
  mkdir -p -- "${DIRECTORIES[@]}"
  printf -- '%s' "$INPUT_SUM" > "$BUILD/.s9/inputs.sum"
  for ((INDEX = 0; INDEX < ${#DEFINITIONS[@]}; INDEX += 3)); do
    NAME="${DEFINITIONS[$INDEX]}"
    if [[ -f $SERVICES/$NAME/template/data/.s9/defs.sum ]]; then
      cp -- "$SERVICES/$NAME/template/data/.s9/defs.sum" "$BUILD/wants/$NAME/.s9/defs.sum"
    fi
  done

  find "$BUILD/wants" -mindepth 1 -maxdepth 1 -printf '%f\0' | "${XARGS[@]}" "$SELF" edges "$STATE" "$BUILD" "${DEFINITIONS[@]}"
  "$TRAVERSAL" --unique . -1 "$BUILD"/wants/* > /dev/null
  PREVIOUS=''
  if [[ -L $TOPOLOGY ]]; then
    PREVIOUS="$(realpath -- "$TOPOLOGY")"
  fi
  ln -sTnfr -- "$BUILD" "$GRAPH/.topology-next"
  mv --no-target-directory -- "$GRAPH/.topology-next" "$TOPOLOGY"
  trap - EXIT
  if [[ -n $PREVIOUS ]]; then
    rm -fr -- "$PREVIOUS"
  fi
  ;&
projection)
  if ! [[ -L $TOPOLOGY ]]; then
    exit
  fi
  PASS="$(mktemp -d -- "$GRAPH/.projection.XXXXXX")"
  trap 'rm -fr -- "$PASS"' EXIT

  for JOB in "$TOPOLOGY"/wants/*; do
    printf -- '%s\0' "$PASS/${JOB##*/}/records"
  done | xargs --null --no-run-if-empty --max-procs=0 -- mkdir --parents --
  find "$PASS" -mindepth 1 -maxdepth 1 -type d -printf '%f\0' | "${XARGS[@]}" "$SELF" evaluate "$STATE" "$PASS"
  ;;
recover)
  LIVE="${1%/.s9/record}"
  PRODUCER="${LIVE%/*}"
  if "${SELF%/*}/dataflow.sh" deliver "$STATE" "${PRODUCER##*/}" "${LIVE##*/}"; then :; fi
  ;;
edges)
  BUILD="$1"
  CONSUMER="${!#}"
  shift -- 1
  declare -A -- JOB_NAMES=()
  while (($# > 1)); do
    JOB_NAMES[$2]="${JOB_NAMES[$2]:-$1}"
    shift -- 3
  done
  for WANT in "$SERVICES/$CONSUMER/template/data/wants/"*; do
    PRODUCER=''
    if TARGET="$(realpath -- "$WANT")"; then
      PRODUCER="${JOB_NAMES[$TARGET]:-}"
    fi
    if [[ -z $PRODUCER ]]; then
      touch -- "$BUILD/wants/$CONSUMER/${WANT##*/}"
      tee >&2 <<- EOF
Unknown dependency: $WANT
EOF
      continue
    fi
    INPUT="$PRODUCER"
    if [[ ${WANT##*/} == =* ]]; then INPUT="=$PRODUCER"; fi
    ln -sTnfr -- "$BUILD/wants/$PRODUCER" "$BUILD/wants/$CONSUMER/$INPUT"
  done
  ;;
evaluate | evaluated)
  PASS="$1"
  JOB="$2"
  ;;&
evaluate)
  exec -- s6-setlock -- "$PASS/$JOB/lock" "$SELF" evaluated "$STATE" "$PASS" "$JOB"
  ;;
evaluated)
  STATUS="$PASS/$JOB/status"
  if [[ -f $STATUS ]]; then exit "$(< "$STATUS")"; fi
  trap 'printf -- "%s" "$?" > "$STATUS"' EXIT
  WANTS=("$TOPOLOGY/wants/$JOB/"*)
  for WANT in "${WANTS[@]}"; do
    if [[ -L $WANT ]]; then
      PRODUCER="${WANT##*/}"
      PRODUCER="${PRODUCER#=}"
      if [[ -f $PASS/$PRODUCER/status ]] && [[ $(< "$PASS/$PRODUCER/status") == 0 ]]; then
        continue
      fi
      printf -- '%s\0' "$PRODUCER"
    fi
  done | "${XARGS[@]}" "$SELF" evaluate "$STATE" "$PASS"
  CACHE="$INPUTS_ROOT/$JOB/.s9/projection"
  if ((${#WANTS[@]})); then
    INPUT_SUM="$(
      {
        printf -- '%s\0' "$STATE"
        if [[ -f $TOPOLOGY/wants/$JOB/.s9/defs.sum ]]; then
          printf -- '%s\0' "$(< "$TOPOLOGY/wants/$JOB/.s9/defs.sum")"
        fi
        for WANT in "${WANTS[@]}"; do
          PRODUCER="${WANT##*/}"
          printf -- '%s\0' "$PRODUCER"
          if [[ -L $WANT ]]; then
            printf -- '%s\0' "$(< "$PASS/${PRODUCER#=}/sum")"
          else
            printf -- '%s\0' missing
          fi
        done
      } | b3sum
    )"
    {
      if [[ -f $CACHE/.sum ]] && [[ $(< "$CACHE/.sum") == "$INPUT_SUM" ]]; then
        find "$CACHE" -mindepth 1 -maxdepth 1 -type f ! -name '.*' -printf '%f %p\0'
      else
        rm -fr -- "$CACHE"
        mkdir -p -- "$CACHE"
        "$SELF" combine "$STATE" "$TOPOLOGY/wants/$JOB" "$PASS" '' | sort --zero-terminated --unique --key=1,1
      fi
    } | "${XARGS[@]}" "$SELF" publish "$STATE" "$TOPOLOGY/wants/$JOB" "$PASS"
    if ! [[ -f $CACHE/.sum ]]; then
      printf -- '%s' "$INPUT_SUM" > "$CACHE/.sum"
    fi
  else
    if [[ -d $CACHE ]]; then rm -fr -- "$CACHE"; fi
    if [[ -f $TOPOLOGY/wants/$JOB/.s9/defs.sum ]]; then
      for SOURCE in "$DEAD"/"$JOB"/*/latest-succ; do
        PARENT="${SOURCE%/*}"
        ln -sTnfr -- "$SOURCE" "$PASS/$JOB/records/${PARENT##*/}"
      done
    fi
  fi
  for OUTPUT in "$PASS"/"$JOB"/records/*/outputs/*; do
    RECORD="${OUTPUT%/outputs/*}"
    if [[ -d $OUTPUT ]] && ! [[ -f $RECORD/.s9/outputs.sum/${OUTPUT##*/} ]]; then
      printf -- '%s\0%s\0' "$RECORD" "${OUTPUT##*/}"
    fi
  done | xargs --null --no-run-if-empty --max-procs=0 --max-args=2 -- "${SELF%/*}/dataflow.sh" hash-row
  RECORDS=("$PASS/$JOB/records/"*)
  {
    if ((${#RECORDS[@]})); then readlink --zero -- "${RECORDS[@]}"; fi
  } | b3sum > "$PASS/$JOB/sum"
  ;;
combine | publish)
  cd -P -- "$1"
  PASS="$2"
  JOB="${PWD##*/}"
  shift -- 2
  ;;&
combine)
  WANTS=(*)
  KEY="$1"
  shift -- 1
  if ! [[ -f .s9/defs.sum ]]; then
    exit
  fi
  INDEX=$(($# / 2))
  if (($#)) && [[ ${*: -2:1} == =* ]]; then
    KEY="${!#}"
    KEY="${KEY##*/}"
  fi
  if ((INDEX < ${#WANTS[@]})); then
    WANT="${WANTS[$INDEX]}"
    PRODUCER="${WANT#=}"
    if ! [[ -L $WANT ]]; then
      if [[ $WANT == =* ]]; then
        exit
      fi
      exec -- "$SELF" combine "$STATE" "$PWD" "$PASS" "$KEY" "$@" "$WANT" ''
    fi
    if [[ $WANT == =* ]] && [[ -n $KEY ]]; then
      ROWS=("$PASS"/"$PRODUCER"/records/*/outputs/"$KEY")
    else
      ROWS=("$PASS"/"$PRODUCER"/records/*/outputs/*)
    fi
    for INDEX in "${!ROWS[@]}"; do
      if ! [[ -d ${ROWS[$INDEX]} ]]; then
        unset 'ROWS[INDEX]'
      fi
    done
    {
      if ((${#ROWS[@]})); then
        realpath --zero -- "${ROWS[@]}"
      fi
    } | "${XARGS[@]}" "$SELF" combine "$STATE" "$PWD" "$PASS" "$KEY" "$@" "$WANT"
    exit
  fi
  INSTANCE="$(
    {
      printf -- '%s\0' "$(< .s9/defs.sum)"
      while (($#)); do
        printf -- '%s\0' "$1" "${2##*/}"
        if [[ -n $2 ]]; then
          SUM="${2%/outputs/*}/.s9/outputs.sum/${2##*/}"
          if ! [[ -s $SUM ]]; then exit 2; fi
          printf -- '%s\0' "$(< "$SUM")"
        fi
        shift -- 2
      done
    } | b3sum | cut --delimiter=' ' --fields=1
  )"
  INPUTS="$(mktemp -- "$PASS/$JOB/input.XXXXXX")"
  printf -- '%s\0' "$@" > "$INPUTS"
  printf -- '%s %s\0' "$INSTANCE" "$INPUTS"
  ;;
publish)
  INSTANCE="${1%% *}"
  CACHE="$INPUTS_ROOT/$JOB/.s9/projection"
  if ! [[ ${1#* } -ef $CACHE/$INSTANCE ]]; then
    mv --no-target-directory -- "${1#* }" "$CACHE/$INSTANCE"
  fi
  if [[ -L $DEAD/$JOB/$INSTANCE/latest-succ ]]; then
    ln -sTnfr -- "$DEAD/$JOB/$INSTANCE/latest-succ" "$PASS/$JOB/records/$INSTANCE"
  fi
  LAUNCH="$SERVICES/$JOB/data/.s9/launch"
  COMPLETED=("$DEAD/$JOB/$INSTANCE/"[0-9]*/exit_status)
  if [[ -L $LAUNCH/$INSTANCE ]] || [[ -d $SERVICES/$JOB/instances/$INSTANCE ]] || [[ -f $STATE/live/$JOB/$INSTANCE/.s9/record ]] || ((${#COMPLETED[@]})); then
    exit
  fi
  INPUTS="$INPUTS_ROOT/$JOB/$INSTANCE"
  mkdir -p -- "$INPUTS_ROOT/$JOB" "$LAUNCH"
  if ! [[ -d $INPUTS ]]; then
    mapfile -d '' -t ARGS < "$CACHE/$INSTANCE"
    set -- "${ARGS[@]}"
    STAGING="$INPUTS_ROOT/$JOB/.$INSTANCE"
    rm -fr -- "$STAGING"
    mkdir -p -- "$STAGING/.s9"
    trap 'rm -fr -- "$STAGING"' EXIT
    cp -- .s9/defs.sum "$STAGING/.s9/defs.sum"
    while (($#)); do
      if [[ -n $2 ]]; then
        ln -sTnfr -- "$2" "$STAGING/${1#=}"
      fi
      shift -- 2
    done
    mv --no-target-directory -- "$STAGING" "$INPUTS"
  fi
  LINK="$(mktemp -- "$LAUNCH/.launch.XXXXXX")"
  trap 'rm -f -- "$LINK"' EXIT
  ln -sTnfr -- "$INPUTS" "$LINK"
  mv --no-target-directory -- "$LINK" "$LAUNCH/$INSTANCE"
  ;;
*)
  set -x
  exit 2
  ;;
esac
