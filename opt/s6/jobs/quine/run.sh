#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob dotglob

SELF="$(realpath -- "$0")"
ROOT="${SELF%/jobs/quine/run.sh}"
TIMEOUT=6000
XARGS=(xargs --null --no-run-if-empty --max-procs=0 -I '{}' --)

case "${RECUR:-}" in
bootstrap)
  RECUR=seed exec -- s6-setlock -t "$TIMEOUT" -- "$SELF" "$SELF" quine -
  ;;
'')
  cd -P -- "${0%/*}/../../../.."
  RECUR=reconcile exec -- s6-setlock -t "$TIMEOUT" -- "$SELF" "$SELF"
  ;;
reconcile)
  trap 's6-svscanctl -h -- "$PWD"' EXIT
  find "$ROOT/jobs" -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' ! -name '.*' -print0 | RECUR=job "${XARGS[@]}" "$SELF" '{}'
  ;;
seed | job)
  NAME="${1##*/}"
  JOB="$(realpath -- "$ROOT/jobs/$NAME")"
  MANAGER="$PWD/$NAME"
  RUN=("$JOB"/run.*)
  if ((${#RUN[@]} != 1)) || ! [[ -f ${RUN[*]} && -x ${RUN[*]} ]]; then
    set -x
    exit 2
  fi

  STAGING="$(mktemp -d -- "$PWD/.$NAME.XXXXXX")"
  trap 'rm -fr -- "$STAGING"' EXIT
  rsync --archive -- "$ROOT/base/" "$STAGING/template/"
  rsync --archive --checksum --exclude=/data/recurring --exclude=/data/oneshot --include='/env/***' --include='/data/***' --exclude='/*' -- "$JOB/" "$STAGING/template/"
  ln -s -- "${RUN[*]}" "$STAGING/template/data/job"
  mkdir -p -- "$STAGING/template/data/recurring"

  if ! [[ -d $MANAGER ]]; then
    s6-instance-maker -- "$STAGING/template" "$STAGING/manager"
    mkdir -p -- "$STAGING/manager/data/done"
    mv -- "$STAGING/manager" "$MANAGER"
  else
    rsync --archive --checksum --delete -- "$STAGING/template/" "$MANAGER/template/"
  fi

  ;;&
seed)
  INSTANCE="$2"
  if ! [[ -d $MANAGER/instances/$INSTANCE ]]; then
    rsync --archive -- "$MANAGER/template/" "$STAGING/instance/"
    mv -- "$STAGING/instance" "$MANAGER/instances/$INSTANCE"
  fi
  if ! [[ -L $MANAGER/instance/$INSTANCE ]]; then
    ln -s -- "../instances/$INSTANCE" "$MANAGER/instance/$INSTANCE"
  fi
  ;;
job)
  if ! s6-svok "$MANAGER"; then
    exit
  fi
  s6-svwait -U -t "$TIMEOUT" -- "$MANAGER"

  RECUR=cleanup find "$MANAGER/data/done" -mindepth 1 -maxdepth 1 ! -name '.*' -exec "$SELF" "$NAME" '{}' +

  for MODE in recurring oneshot; do
    if [[ -d $JOB/data/$MODE ]]; then
      find "$JOB/data/$MODE" -mindepth 1 -maxdepth 1 -type l ! -name '.*' -print0 | RECUR="$MODE" "${XARGS[@]}" "$SELF" "$NAME" '{}'
    fi
  done
  ;;
cleanup)
  MANAGER="$PWD/$1"
  shift -- 1
  for SVC in "$@"; do
    INSTANCE="${SVC##*/}"
    s6-instance-delete -- "$MANAGER" "$INSTANCE"
    rm -fr -- "$SVC"
  done
  ;;
recurring | oneshot)
  JOB="$ROOT/jobs/$1"
  MANAGER="$PWD/$1"
  INSTANCE="${2##*/}"
  SERVICE="$MANAGER/instances/$INSTANCE"
  RECURRING="$JOB/data/recurring/$INSTANCE"
  ONESHOT="$JOB/data/oneshot/$INSTANCE"

  if [[ -L $RECURRING && -L $ONESHOT ]]; then
    tee >&2 <<- EOF
Conflicting Requests:
$RECURRING
$ONESHOT
EOF
    exit 2
  fi
  ;;&
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
