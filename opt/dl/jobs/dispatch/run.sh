#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
XARGS=(xargs --null --no-run-if-empty --max-procs=0 -I '{}' --)

case "${RECUR:-}" in
'')
  find "$1" -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' ! -name '.*' -print0 | RECUR=step "${XARGS[@]}" "$SELF" '{}'
  ;;
step)
  unset -- RECUR
  if ! [[ -x dispatch.sh ]]; then
    set -x
    exit 2
  fi
  if [[ -d records ]]; then
    "${SELF%/*}/data/gc.sh" "$PWD/records"
  fi
  exec -- ./dispatch.sh
  ;;
*)
  set -x
  exit 2
  ;;
esac
