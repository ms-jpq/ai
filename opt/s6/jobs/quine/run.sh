#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

SELF="$(realpath -- "$0")"
ROOT="${SELF%/jobs/quine/run.sh}"
TIMEOUT=6000
LOCK='.reconcile.lock'
XARGS=(xargs --null --no-run-if-empty --max-procs=0 -I '{}' --)

case "${RECUR:-}" in
bootstrap)
  RECUR=seed exec -- s6-setlock -t "$TIMEOUT" -- "$LOCK" "$SELF" quine -
  ;;
'')
  cd -P -- "${0%/*}/../../../.."
  RECUR=reconcile exec -- s6-setlock -t "$TIMEOUT" -- "$LOCK" "$SELF"
  ;;
reconcile)
  trap 's6-svscanctl -h -- "$PWD"' EXIT
  find "$ROOT/jobs" "$PWD" -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' ! -name '.*' -printf '%f\0' | sort --zero-terminated --unique | RECUR=job "${XARGS[@]}" "$SELF" '{}'
  ;;
seed | job | cleanup | recurring | oneshot | refresh)
  NAME="${1##*/}"
  JOB="$ROOT/jobs/$NAME"
  MANAGER="$PWD/$NAME"
  TEMPLATE="$MANAGER/template"
  INSTANCES="$MANAGER/instances"
  DONE="$MANAGER/data/done"
  ;;&
seed | job)
  if [[ $RECUR == seed ]] || [[ -d $JOB ]]; then
    JOB="$(realpath -- "$JOB")"
    RUN=("$JOB"/run.*)
    if ((${#RUN[@]} != 1)) || ! [[ -f ${RUN[*]} ]] || ! [[ -x ${RUN[*]} ]]; then
      set -x
      exit 2
    fi

    STAGING="$(mktemp -d -- "$PWD/.$NAME.XXXXXX")"
    BUILD="$STAGING/template"
    trap 'rm -fr -- "$STAGING"' EXIT
    rsync --archive -- "$ROOT/base/" "$BUILD/"
    rsync --archive --checksum --exclude=/data/launch --include='/env/***' --include='/data/***' --exclude='/*' -- "$JOB/" "$BUILD/"
    if [[ ${RUN[*]} -ef $SELF ]]; then
      ln -sTnf -- "${RUN[*]}" "$BUILD/data/job"
    else
      cp --dereference --preserve=mode,timestamps -- "${RUN[*]}" "$BUILD/data/job"
    fi
    mkdir -p -- "$BUILD/data/launch/recurring"
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu --create --file=- --directory="$BUILD" . | b3sum > "$STAGING/.sum"
    mv -- "$STAGING/.sum" "$BUILD/.sum"

    if ! [[ -d $MANAGER ]]; then
      s6-instance-maker -- "$BUILD" "$STAGING/manager"
      mkdir -p -- "$STAGING/manager/data/done"
      mv -- "$STAGING/manager" "$MANAGER"
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
  if ! [[ -L $MANAGER/instance/$INSTANCE ]]; then
    ln -sTnfr -- "$INSTANCES/$INSTANCE" "$MANAGER/instance/$INSTANCE"
  fi
  ;;
job)
  if ! s6-svok "$MANAGER"; then
    exit
  fi
  s6-svwait -U -t "$TIMEOUT" -- "$MANAGER"

  RECUR=cleanup find "$DONE" -mindepth 1 -maxdepth 1 ! -name '.*' -exec "$SELF" "$NAME" '{}' +
  find "$INSTANCES" -mindepth 1 -maxdepth 1 -type d -print0 | RECUR=refresh "${XARGS[@]}" "$SELF" "$NAME" '{}'
  if ! [[ -d $JOB ]]; then
    exit
  fi

  for MODE in recurring oneshot; do
    for SOURCE in "$JOB" "$MANAGER"; do
      if [[ -d $SOURCE/data/launch/$MODE ]]; then
        find "$SOURCE/data/launch/$MODE/" -mindepth 1 -maxdepth 1 -type l ! -name '.*' -printf '%f\0'
      fi
    done | sort --zero-terminated --unique | RECUR="$MODE" "${XARGS[@]}" "$SELF" "$NAME" '{}'
  done
  ;;
cleanup)
  shift -- 1
  for SVC in "$@"; do
    INSTANCE="${SVC##*/}"
    s6-instance-delete -- "$MANAGER" "$INSTANCE"
    rm -fr -- "$SVC"
  done
  ;;
recurring | oneshot | refresh)
  INSTANCE="${2##*/}"
  SERVICE="$INSTANCES/$INSTANCE"
  DATA="$SERVICE/data"
  RECURRING="$JOB/data/launch/recurring/$INSTANCE"
  ONESHOT="$JOB/data/launch/oneshot/$INSTANCE"
  if ! [[ -L $RECURRING ]]; then
    RECURRING="$MANAGER/data/launch/recurring/$INSTANCE"
  fi
  if ! [[ -L $ONESHOT ]]; then
    ONESHOT="$MANAGER/data/launch/oneshot/$INSTANCE"
  fi

  if [[ -L $RECURRING ]] && [[ -L $ONESHOT ]]; then
    tee >&2 <<- EOF
Conflicting Requests:
$RECURRING
$ONESHOT
EOF
    exit 2
  fi
  ;;&
refresh)
  if ! [[ -d $DATA/launch/recurring ]] || [[ $DATA/job -ef $SELF ]]; then
    exit
  fi
  if [[ -d $JOB ]] && [[ -L $RECURRING ]] && ! [[ -f $SERVICE/down ]] && cmp --silent -- "$TEMPLATE/.sum" "$SERVICE/.sum"; then
    exit
  fi
  touch -- "$SERVICE/down"
  s6-instance-control -O -- "$MANAGER" "$INSTANCE"
  STATUS="$(s6-svstat -o up,wantedup -- "$SERVICE")"
  if [[ $STATUS == 'false false' ]]; then
    s6-svwait -D -t "$TIMEOUT" -- "$SERVICE"
    s6-instance-delete -- "$MANAGER" "$INSTANCE"
  fi
  ;;
recurring)
  if ! [[ -d $SERVICE ]]; then
    s6-instance-create -t "$TIMEOUT" -- "$MANAGER" "$INSTANCE"
  elif ! [[ -d $DATA/launch/recurring ]]; then
    printf -- 'Instance still belongs to a oneshot: %s@%s\n' "${JOB##*/}" "$INSTANCE" >&2
    exit 2
  fi
  ;;
oneshot)
  if ! [[ -d $SERVICE ]]; then
    s6-instance-create -D -t "$TIMEOUT" -- "$MANAGER" "$INSTANCE"
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

  rm -fr -- "$DATA/launch/recurring"
  s6-svc -wU -T "$TIMEOUT" -U -- "$SERVICE/log"
  rm -- "$ONESHOT"
  s6-instance-control -wu -T "$TIMEOUT" -o -- "$MANAGER" "$INSTANCE"
  ;;
*)
  set -x
  exit 2
  ;;
esac
