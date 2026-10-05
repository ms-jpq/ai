#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

NAME="${1##*/}"

SELF="$(realpath -- "$0")"
ROOT="${SELF%/jobs/quine/run.sh}"
LOCK='./.reconcile.lock'
JOB="$ROOT/jobs/$NAME"
SUPERVISOR="$PWD/$NAME"
TEMPLATE="$SUPERVISOR/template"
INSTANCES="$SUPERVISOR/instances"
TIMEOUT=6000
XARGS=(xargs --null --no-run-if-empty --max-procs=0 -I '{}' --)

case "${RECUR:-}" in
bootstrap)
  RECUR=seed exec -- s6-setlock -t "$TIMEOUT" -- "$LOCK" "$SELF" "$NAME" -
  ;;
'')
  cd -P -- "${0%/*}/../../../.."
  RECUR=reconcile exec -- s6-setlock -t "$TIMEOUT" -- "$LOCK" "$SELF" "$NAME"
  ;;
reconcile)
  trap 's6-svscanctl -h -- "$PWD"' EXIT
  find "$ROOT/jobs" "$PWD" -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' ! -name '.*' -printf '%f\0' | sort --zero-terminated --unique | RECUR=job "${XARGS[@]}" "$SELF" '{}'
  "$ROOT/base/data/topology.sh" compile "$PWD/.." "$ROOT/jobs"
  ;;
seed | job)
  if [[ $RECUR == seed ]] || [[ -d $JOB ]]; then
    JOB="$(realpath -- "$JOB")"
    STAGING="$(mktemp -d -- "$PWD/.$NAME.XXXXXX")"
    trap 'rm -fr -- "$STAGING"' EXIT
    RUN=("$JOB"/run.*)
    if ((${#RUN[@]} != 1)) || ! [[ -f ${RUN[*]} ]] || ! [[ -x ${RUN[*]} ]]; then
      set -x
      exit 2
    fi
    BUILD="$(RECUR='' "$ROOT/libexec/p-cp.sh" "$ROOT/base" "$STAGING/template")"
    cp --remove-destination --dereference --preserve=mode,timestamps -- "$ROOT/libexec/p-cp.sh" "$BUILD/data/"
    rsync --archive --checksum --exclude=/data/launch --exclude=/data/.s9 --include='/env/***' --include='/data/***' --exclude='/*' -- "$JOB/" "$BUILD/"
    for WANT in "$JOB"/data/wants/*; do
      PRODUCER="$(realpath --canonicalize-missing -- "$WANT")"
      ln -sTnf -- "$PRODUCER" "$BUILD/data/wants/${WANT##*/}"
    done
    if [[ ${RUN[*]} -ef $SELF ]]; then
      ln -sTnf -- "${RUN[*]}" "$BUILD/data/.run"
    else
      cp --dereference --preserve=mode,timestamps -- "${RUN[*]}" "$BUILD/data/.run"
    fi
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu --create --file=- --directory="$BUILD" . | b3sum > "$STAGING/defs.sum"
    mv -- "$STAGING/defs.sum" "$BUILD/data/.s9/defs.sum"
    ln -sTnf -- "$JOB" "$BUILD/data/.s9/source"

    if ! [[ -d $SUPERVISOR ]]; then
      s6-instance-maker -- "$BUILD" "$STAGING/manager"
      mv --no-target-directory -- "$STAGING/manager" "$SUPERVISOR"
    else
      rsync --archive --checksum --delete -- "$BUILD/" "$TEMPLATE/"
    fi
  fi

  ;;&
seed)
  INSTANCE="$2"
  if ! [[ -d $INSTANCES/$INSTANCE ]]; then
    rsync --archive -- "$TEMPLATE/" "$STAGING/instance/"
    mv --no-target-directory -- "$STAGING/instance" "$INSTANCES/$INSTANCE"
  fi
  if ! [[ -L $SUPERVISOR/instance/$INSTANCE ]]; then
    ln -sTnfr -- "$INSTANCES/$INSTANCE" "$SUPERVISOR/instance/$INSTANCE"
  fi
  ;;
job)
  if ! s6-svok "$SUPERVISOR"; then
    exit
  fi
  s6-svwait -U -t "$TIMEOUT" -- "$SUPERVISOR"

  {
    find "$INSTANCES" -mindepth 1 -maxdepth 1 ! -name '.*' -printf '%f\0'
    for SOURCE in "$JOB" "$SUPERVISOR"; do
      if [[ -d $SOURCE/data/launch ]]; then
        find "$SOURCE/data/launch/" -mindepth 1 -maxdepth 1 -type l ! -name '.*' -printf '%f\0'
      fi
    done
  } | sort --zero-terminated --unique | RECUR=instance "${XARGS[@]}" "$SELF" "$NAME" '{}' "$JOB"
  ;;
cleanup)
  INSTANCE="$2"
  DELETE=(s6-instance-delete -t "$TIMEOUT")
  if ! s6-svok "$INSTANCES/$INSTANCE"; then
    DELETE+=(-X)
  fi
  "${DELETE[@]}" -- "$SUPERVISOR" "$INSTANCE"
  ;;
instance)
  INSTANCE="${2##*/}"
  JOB="$3"
  SERVICE="$INSTANCES/$INSTANCE"
  DATA="$SERVICE/data"
  DIED="$DATA/.s9/died"
  REQUEST="$JOB/data/launch/$INSTANCE"
  if ! [[ -L $REQUEST ]]; then
    REQUEST="$SUPERVISOR/data/launch/$INSTANCE"
  fi

  if [[ -f ../live/$NAME/$INSTANCE/.s9/record ]]; then
    "$ROOT/base/data/dataflow.sh" deliver "$PWD/.." "$NAME" "$INSTANCE"
  fi

  if [[ -L $DIED ]] || { [[ -d $SERVICE ]] && ! s6-svok "$SERVICE"; }; then
    RECUR=cleanup "$0" "$NAME" "$INSTANCE"
  fi

  if [[ -d $SERVICE ]] && (($(< "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC") >= 0)); then
    if [[ $DATA/.run -ef $SELF ]]; then
      exit
    fi
    if [[ -d $JOB ]] && [[ -L $REQUEST ]] && ! [[ -f $SERVICE/down ]] && cmp --silent -- "$TEMPLATE/data/.s9/defs.sum" "$DATA/.s9/defs.sum"; then
      exit
    fi
    touch -- "$SERVICE/down"
    STATUS="$(s6-svstat -o up,wantedup -- "$SERVICE")"
    case "$STATUS" in
    'false false')
      ;;
    *' true')
      s6-instance-control -d -- "$SUPERVISOR" "$INSTANCE"
      exit
      ;;
    *)
      exit
      ;;
    esac
    s6-svwait -D -t "$TIMEOUT" -- "$SERVICE"
    RECUR=cleanup "$0" "$NAME" "$INSTANCE"
  fi
  if ! [[ -L $DATA/launch ]]; then
    if ! [[ -d $JOB ]] || ! [[ -L $REQUEST ]]; then
      exit
    fi
  fi
  if ! [[ -d $SERVICE ]]; then
    DEFINITION="$REQUEST/.s9/defs.sum"
    if [[ -f $DEFINITION ]] && ! cmp --silent -- "$DEFINITION" "$TEMPLATE/data/.s9/defs.sum"; then
      rm -fr -- "$REQUEST"
      exit
    fi
    if (($(< "$TEMPLATE/env/S9_ON_UNIT_INACTIVE_SEC") >= 0)); then
      exec -- s6-instance-create -t "$TIMEOUT" -- "$SUPERVISOR" "$INSTANCE"
    fi
    s6-instance-create -D -t "$TIMEOUT" -- "$SUPERVISOR" "$INSTANCE"
  else
    STATUS="$(s6-svstat -o up -- "$SERVICE")"
    if ! [[ -f $SERVICE/down ]] || [[ $STATUS == true ]]; then
      exit
    fi
    s6-svwait -D -t "$TIMEOUT" -- "$SERVICE"
    if [[ -L $DIED ]]; then
      exit
    fi
  fi

  s6-svc -wU -T "$TIMEOUT" -U -- "$SERVICE/log"
  if ! [[ -L $DATA/launch ]]; then
    TARGET="$(readlink -- "$REQUEST")"
    if [[ $TARGET != /* ]]; then
      STAGING="$(mktemp -- "${REQUEST%/*}/.launch.XXXXXX")"
      trap 'rm -f -- "$STAGING"' EXIT
      ln -sTnf -- "${REQUEST%/*}/$TARGET" "$STAGING"
      mv --no-target-directory -- "$STAGING" "$REQUEST"
    fi
    mv --no-target-directory -- "$REQUEST" "$DATA/launch"
  fi
  s6-instance-control -wu -T "$TIMEOUT" -o -- "$SUPERVISOR" "$INSTANCE"
  ;;
*)
  set -x
  exit 2
  ;;
esac
