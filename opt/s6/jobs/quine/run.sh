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
DONE="$SUPERVISOR/data/done"
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
  ;;
seed | job)
  if [[ $RECUR == seed ]] || [[ -d $JOB ]]; then
    JOB="$(realpath -- "$JOB")"
    RUN=("$JOB"/run.*)
    if ((${#RUN[@]} != 1)) || ! [[ -f ${RUN[*]} ]] || ! [[ -x ${RUN[*]} ]]; then
      set -x
      exit 2
    fi

    STAGING="$(mktemp -d -- "$PWD/.$NAME.XXXXXX")"
    trap 'rm -fr -- "$STAGING"' EXIT
    BUILD="$STAGING/template"

    rsync --archive -- "$ROOT/base/" "$BUILD/"
    rsync --archive --checksum --exclude=/data/launch --include='/env/***' --include='/data/***' --exclude='/*' -- "$JOB/" "$BUILD/"
    if [[ ${RUN[*]} -ef $SELF ]]; then
      ln -sTnf -- "${RUN[*]}" "$BUILD/data/job"
    else
      cp --dereference --preserve=mode,timestamps -- "${RUN[*]}" "$BUILD/data/job"
    fi
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu --create --file=- --directory="$BUILD" . | b3sum > "$STAGING/.sum"
    mv -- "$STAGING/.sum" "$BUILD/.sum"

    if ! [[ -d $SUPERVISOR ]]; then
      s6-instance-maker -- "$BUILD" "$STAGING/manager"
      mkdir -p -- "$STAGING/manager/data/done"
      mv -- "$STAGING/manager" "$SUPERVISOR"
    else
      rsync --archive --checksum --delete -- "$BUILD/" "$TEMPLATE/"
    fi
  fi

  ;;&
seed)
  INSTANCE="$2"
  if ! [[ -d $INSTANCES/$INSTANCE ]]; then
    rsync --archive -- "$TEMPLATE/" "$STAGING/instance/"
    mv -- "$STAGING/instance" "$INSTANCES/$INSTANCE"
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

  RECUR=cleanup find "$DONE" -mindepth 1 -maxdepth 1 ! -name '.*' -exec "$SELF" "$NAME" '{}' +
  {
    find "$INSTANCES" -mindepth 1 -maxdepth 1 -type d -printf '%f\0'
    for SOURCE in "$JOB" "$SUPERVISOR"; do
      if [[ -d $SOURCE/data/launch ]]; then
        find "$SOURCE/data/launch/" -mindepth 1 -maxdepth 1 -type l ! -name '.*' -printf '%f\0'
      fi
    done
  } | sort --zero-terminated --unique | RECUR=instance "${XARGS[@]}" "$SELF" "$NAME" '{}' "$JOB"
  ;;
cleanup)
  shift -- 1
  for INSTANCE in "$@"; do
    INSTANCE="${INSTANCE##*/}"
    DELETE=(s6-instance-delete -t "$TIMEOUT")
    if ! s6-svok "$INSTANCES/$INSTANCE"; then
      DELETE+=(-X)
    fi
    "${DELETE[@]}" -- "$SUPERVISOR" "$INSTANCE"
    rm -fr -- "${DONE:?}/$INSTANCE"
  done
  ;;
instance)
  INSTANCE="${2##*/}"
  JOB="$3"
  SERVICE="$INSTANCES/$INSTANCE"
  DATA="$SERVICE/data"
  REQUEST="$JOB/data/launch/$INSTANCE"
  if ! [[ -L $REQUEST ]]; then
    REQUEST="$SUPERVISOR/data/launch/$INSTANCE"
  fi

  if [[ -d $SERVICE ]] && ! s6-svok "$SERVICE"; then
    RECUR=cleanup "$0" "$NAME" "$INSTANCE"
  fi

  if [[ -d $SERVICE ]] && (($(< "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC") >= 0)); then
    if [[ $DATA/job -ef $SELF ]]; then
      exit
    fi
    if [[ -d $JOB ]] && [[ -L $REQUEST ]] && ! [[ -f $SERVICE/down ]] && cmp --silent -- "$TEMPLATE/.sum" "$SERVICE/.sum"; then
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
    if [[ -f $DONE/$INSTANCE ]]; then
      exit
    fi
  fi

  s6-svc -wU -T "$TIMEOUT" -U -- "$SERVICE/log"
  if ! [[ -L $DATA/launch ]]; then
    mv --no-target-directory -- "$REQUEST" "$DATA/launch"
  fi
  s6-instance-control -wu -T "$TIMEOUT" -o -- "$SUPERVISOR" "$INSTANCE"
  ;;
*)
  set -x
  exit 2
  ;;
esac
