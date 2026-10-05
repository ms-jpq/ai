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
CARTESIAN="$GRAPH/cartesian-inputs"
DEAD="$STATE/dead"

case "$ACTION" in
compile | projection)
  mkdir -p -- "$SERVICES"
  if [[ ${RECUR:-} != reconcile ]]; then
    RECUR=reconcile exec -- s6-setlock -t "$((S9_GRAPH_TIMEOUT * 1000))" -- "$SERVICES/.reconcile.lock" "$SELF" "$ACTION" "$STATE" "$@"
  fi
  mkdir -p -- "$GRAPH"
  ;;&
compile)
  JOBS="$1"
  for RECORD in "$STATE"/live/*/*/.s9/record; do
    LIVE="${RECORD%/.s9/record}"
    PRODUCER="${LIVE%/*}"
    "${SELF%/*}/dataflow.sh" deliver "$STATE" "${PRODUCER##*/}" "${LIVE##*/}" || continue
  done

  BUILD="$(mktemp -d -- "$GRAPH/.topology.XXXXXX")"
  trap 'rm -fr -- "$BUILD"' EXIT
  mkdir -- "$BUILD/wants" "$BUILD/wanted-by"

  declare -A -- JOB_NAMES=()
  for JOB in "$JOBS"/*; do
    if [[ -d $JOB ]]; then
      NAME="${JOB##*/}"
      SOURCE="$SERVICES/$NAME/template/data/.s9/source"
      if ! [[ -L $SOURCE ]]; then
        continue
      fi
      TARGET="$(readlink -- "$SOURCE")"
      JOB_NAMES[$TARGET]="${JOB_NAMES[$TARGET]:-$NAME}"
      mkdir -p -- "$BUILD/wants/$NAME/.s9" "$BUILD/wanted-by/$NAME"
      if [[ -f $SERVICES/$NAME/template/data/.s9/defs.sum ]]; then
        cp -- "$SERVICES/$NAME/template/data/.s9/defs.sum" "$BUILD/wants/$NAME/.s9/defs.sum"
      fi
    fi
  done

  for JOB in "$BUILD"/wants/*; do
    CONSUMER="${JOB##*/}"
    for WANT in "$SERVICES"/"$CONSUMER"/template/data/wants/*; do
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
      ln -sTnfr -- "$BUILD/wants/$PRODUCER" "$BUILD/wants/$CONSUMER/$PRODUCER"
      ln -sTnfr -- "$BUILD/wanted-by/$CONSUMER" "$BUILD/wanted-by/$PRODUCER/$CONSUMER"
    done
  done

  mkdir -- "$BUILD/check"
  for JOB in "$BUILD"/wants/*; do
    "$SELF" visit "$STATE" "$JOB" "$BUILD/check" :
  done
  rm -fr -- "$BUILD/check"
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
  shift -- 1
  ;&
projection)
  if ! [[ -L $TOPOLOGY ]]; then
    exit
  fi
  PASS="$(mktemp -d -- "$GRAPH/.projection.XXXXXX")"
  trap 'rm -fr -- "$PASS"' EXIT

  if (($#)); then
    mkdir -- "$PASS/.selected"
    for PRODUCER in "$@"; do
      for CONSUMER in "$TOPOLOGY"/wanted-by/"$PRODUCER"/*; do
        "$SELF" visit "$STATE" "$CONSUMER" "$PASS/.selected" :
      done
    done
  else
    ln -sTnfr -- "$TOPOLOGY/wants" "$PASS/.selected"
  fi
  for JOB in "$PASS"/.selected/*; do
    "$SELF" visit "$STATE" "$TOPOLOGY/wants/${JOB##*/}" "$PASS" "$SELF" combine "$STATE"
  done
  ;;
visit | combine)
  cd -P -- "$1"
  PASS="$2"
  JOB="${PWD##*/}"
  shift -- 2
  WANTS=(*)
  ;;&
visit)
  if [[ -f $PASS/$JOB/done ]]; then
    exit
  fi
  if [[ -d $PASS/$JOB ]]; then
    tee >&2 <<- EOF
Dependency cycle at $JOB
EOF
    exit 2
  fi
  mkdir -p -- "$PASS/$JOB/records"
  for WANT in "${WANTS[@]}"; do
    if [[ -L $WANT ]]; then
      "$SELF" visit "$STATE" "$PWD/$WANT" "$PASS" "$@"
    fi
  done
  "$@" "$PWD" "$PASS"
  touch -- "$PASS/$JOB/done"
  ;;
combine)
  if ! [[ -f .s9/defs.sum ]]; then
    exit
  fi
  if ((${#WANTS[@]} == 0)); then
    for SOURCE in "$DEAD"/"$JOB"/*/latest-succ; do
      PARENT="${SOURCE%/*}"
      ln -sTnfr -- "$SOURCE" "$PASS/$JOB/records/${PARENT##*/}"
    done
    exit
  fi
  INDEX=$(($# / 2))
  if ((INDEX < ${#WANTS[@]})); then
    PRODUCER="${WANTS[$INDEX]}"
    if ! [[ -L $PRODUCER ]]; then
      exec -- "$SELF" combine "$STATE" "$PWD" "$PASS" "$@" "$PRODUCER" ''
    fi
    for OUTPUT in "$PASS"/"$PRODUCER"/records/*/outputs/*; do
      if ! [[ -d $OUTPUT ]]; then
        continue
      fi
      OUTPUT="$(realpath -- "$OUTPUT")"
      "$SELF" combine "$STATE" "$PWD" "$PASS" "$@" "$PRODUCER" "$OUTPUT"
    done
    exit
  fi
  INSTANCE="$(
    {
      printf -- '%s\0' "$(< .s9/defs.sum)"
      while (($#)); do
        printf -- '%s\0' "$1" "${2##*/}"
        if [[ -n $2 ]]; then
          tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu --dereference --hard-dereference --create --file=- --directory="$2" . || exit "$?"
        fi
        shift -- 2
      done
    } | b3sum | cut --delimiter=' ' --fields=1
  )"
  if [[ -L $DEAD/$JOB/$INSTANCE/latest-succ ]]; then
    ln -sTnfr -- "$DEAD/$JOB/$INSTANCE/latest-succ" "$PASS/$JOB/records/$INSTANCE"
  fi
  if ! [[ -d $PASS/.selected/$JOB ]]; then
    exit
  fi
  LAUNCH="$SERVICES/$JOB/data/launch"
  COMPLETED=("$DEAD/$JOB/$INSTANCE/"[0-9]*/exit_status)
  if [[ -L $LAUNCH/$INSTANCE ]] || [[ -d $SERVICES/$JOB/instances/$INSTANCE ]] || [[ -f $STATE/live/$JOB/$INSTANCE/.s9/record ]] || ((${#COMPLETED[@]})); then
    exit
  fi
  INPUTS="$CARTESIAN/$JOB/$INSTANCE"
  mkdir -p -- "$CARTESIAN/$JOB" "$LAUNCH"
  if ! [[ -d $INPUTS ]]; then
    STAGING="$CARTESIAN/$JOB/.$INSTANCE"
    rm -fr -- "$STAGING"
    mkdir -p -- "$STAGING/.s9"
    trap 'rm -fr -- "$STAGING"' EXIT
    cp -- .s9/defs.sum "$STAGING/.s9/defs.sum"
    while (($#)); do
      if [[ -n $2 ]]; then
        ln -sTnfr -- "$2" "$STAGING/$1"
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
