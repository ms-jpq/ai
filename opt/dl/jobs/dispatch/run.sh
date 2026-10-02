#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
XARGS=(xargs --null --no-run-if-empty --max-procs=0 -I '{}' --)

case "${RECUR:-}" in
'')
  find . -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' ! -name '.*' -print0 | RECUR=step "${XARGS[@]}" "$SELF" '{}'
  ;;
step)
  cd -P -- "$1"
  if [[ -d records ]]; then
    "${SELF%/*}/data/gc.sh" "$PWD/records"
  fi
  if [[ -f dispatch.sh ]]; then
    unset RECUR
    exec -- s6-envdir -- env ./dispatch.sh
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
