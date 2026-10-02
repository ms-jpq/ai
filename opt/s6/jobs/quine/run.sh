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
    trap 'rm -fr -- "$STAGING"' EXIT
    rsync --archive -- "$ROOT/base/" "$STAGING/template/"
    rsync --archive --checksum --exclude=/data/recurring --exclude=/data/oneshot --include='/env/***' --include='/data/***' --exclude='/*' -- "$JOB/" "$STAGING/template/"
    if [[ ${RUN[*]} -ef $SELF ]]; then
      ln -sTnf -- "${RUN[*]}" "$STAGING/template/data/job"
    else
      cp --dereference --preserve=mode,timestamps -- "${RUN[*]}" "$STAGING/template/data/job"
    fi
    mkdir -p -- "$STAGING/template/data/recurring"
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --format=gnu --create --file=- --directory="$STAGING/template" . | b3sum > "$STAGING/.sum"
    mv -- "$STAGING/.sum" "$STAGING/template/.sum"

    if ! [[ -d $MANAGER ]]; then
      s6-instance-maker -- "$STAGING/template" "$STAGING/manager"
      mkdir -p -- "$STAGING/manager/data/done"
      mv -- "$STAGING/manager" "$MANAGER"
    else
      rsync --archive --checksum --delete -- "$STAGING/template/" "$MANAGER/template/"
    fi
  fi

  ;;&
seed)
  INSTANCE="$2"
  if ! [[ -d $MANAGER/instances/$INSTANCE ]]; then
    rsync --archive -- "$MANAGER/template/" "$STAGING/instance/"
    mv -- "$STAGING/instance" "$MANAGER/instances/$INSTANCE"
  fi
  if ! [[ -L $MANAGER/instance/$INSTANCE ]]; then
    ln -sTnfr -- "$MANAGER/instances/$INSTANCE" "$MANAGER/instance/$INSTANCE"
  fi
  ;;
job)
  if ! s6-svok "$MANAGER"; then
    exit
  fi
  s6-svwait -U -t "$TIMEOUT" -- "$MANAGER"

  RECUR=cleanup find "$MANAGER/data/done" -mindepth 1 -maxdepth 1 ! -name '.*' -exec "$SELF" "$NAME" '{}' +
  find "$MANAGER/instances" -mindepth 1 -maxdepth 1 -type d -print0 | RECUR=refresh "${XARGS[@]}" "$SELF" "$NAME" '{}'
  if ! [[ -d $JOB ]]; then
    exit
  fi

  for MODE in recurring oneshot; do
    for SOURCE in "$JOB" "$MANAGER"; do
      if [[ -d $SOURCE/data/$MODE ]]; then
        find "$SOURCE/data/$MODE/" -mindepth 1 -maxdepth 1 -type l ! -name '.*' -printf '%f\0'
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
  SERVICE="$MANAGER/instances/$INSTANCE"
  RECURRING="$JOB/data/recurring/$INSTANCE"
  ONESHOT="$JOB/data/oneshot/$INSTANCE"
  if ! [[ -L $RECURRING ]]; then
    RECURRING="$MANAGER/data/recurring/$INSTANCE"
  fi
  if ! [[ -L $ONESHOT ]]; then
    ONESHOT="$MANAGER/data/oneshot/$INSTANCE"
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
  if ! [[ -d $SERVICE/data/recurring ]] || [[ $SERVICE/data/job -ef $SELF ]]; then
    exit
  fi
  if [[ -d $JOB ]] && [[ -L $RECURRING ]] && ! [[ -f $SERVICE/down ]] && cmp --silent -- "$MANAGER/template/.sum" "$SERVICE/.sum"; then
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
  elif ! [[ -d $SERVICE/data/recurring ]]; then
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
    if [[ -f $MANAGER/data/done/$INSTANCE ]]; then
      exit
    fi
  fi

  rm -fr -- "$SERVICE/data/recurring"
  s6-svc -wU -T "$TIMEOUT" -U -- "$SERVICE/log"
  rm -- "$ONESHOT"
  s6-instance-control -wu -T "$TIMEOUT" -o -- "$MANAGER" "$INSTANCE"
  ;;
*)
  set -x
  exit 2
  ;;
esac
