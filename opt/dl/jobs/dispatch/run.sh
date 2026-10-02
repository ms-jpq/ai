#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${S67_JOBS_DIR?}"

SELF="$(realpath -- "$0")"
XARGS=(xargs --null --no-run-if-empty --max-procs=0 -I '{}' --)

case "${RECUR:-}" in
'')
  find "$1" -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' ! -name '.*' -print0 | RECUR=step "${XARGS[@]}" "$SELF" '{}'
  ;;
step)
  unset -- RECUR
  JOB="$(realpath --canonicalize-missing -- "$S67_JOBS_DIR/${1##*/}")"
  cd -P -- "$1"
  if ! [[ -x dispatch.sh ]]; then
    set -x
    exit 2
  fi
  "${SELF%/*}/data/service-template.sh" "$PWD" "$JOB"
  mkdir -p -- "$JOB/data/recurring" "$JOB/data/oneshot"
  "${SELF%/*}/data/gc.sh" "$PWD/records"
  exec -- ./dispatch.sh "$JOB/data"
  ;;
*)
  set -x
  exit 2
  ;;
esac
