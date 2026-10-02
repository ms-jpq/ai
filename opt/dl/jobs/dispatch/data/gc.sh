#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
XARGS=(xargs --null --no-run-if-empty --max-procs=0 -I '{}' --)

case "${RECUR:-}" in
'')
  cd -P -- "$1"
  if [[ -d .versions ]]; then
    find .versions -mindepth 1 -maxdepth 1 -type d -print0 | RECUR=1 "${XARGS[@]}" "$SELF" '{}'
  fi
  ;;
1)
  find "$1" -mindepth 3 -maxdepth 3 -type f -path '*/output/exit_status' -printf '%T@ %p\0' | LC_ALL=C.UTF-8 sort --zero-terminated --numeric-sort --reverse | tail --zero-terminated --lines=+3 | cut --zero-terminated --delimiter=' ' --fields=2- | RECUR=2 "${XARGS[@]}" "$SELF" '{}'
  ;;
2)
  OUTPUT="${1%/*}"
  REVISION="${OUTPUT%/*}"
  if ! [[ $REVISION -ef ${REVISION%/*}/latest ]]; then
    find "$1" ! -newermt '30 minutes ago' -exec rm -fr -- "$REVISION" ';'
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
