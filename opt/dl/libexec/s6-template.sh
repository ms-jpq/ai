#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

SRC="$(realpath -- "$1")"
DST="${2%/}"
XARGS=(xargs --null --no-run-if-empty --max-procs=0 -I '{}' --)

case "${RECUR:-}" in
'')
  mkdir -p -- "$DST"
  RECUR=1 find "$SRC" -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' ! -name '.*' -printf '%f\0' | "${XARGS[@]}" "$0" "$SRC/{}" "$DST/{}"
  ;;
1)
  RUN=("$SRC"/run.*)
  if ((${#RUN[@]} != 1)) || ! [[ -f ${RUN[*]} ]] || ! [[ -x ${RUN[*]} ]]; then
    set -x
    exit 2
  fi

  VERSIONS="${DST%/*}/.versions"
  mkdir -p -- "$VERSIONS"

  REVISION="$(mktemp -d -- "$VERSIONS/${DST##*/}.XXXXXX")"
  LINK="${DST%/*}/.${REVISION##*/}.link"
  trap 'rm -f -- "$LINK"' EXIT

  rsync --archive --include='/env/***' --include='/data/***' --exclude='/*' -- "$SRC/" "$REVISION/"
  cp --preserve=mode,timestamps -- "${RUN[*]}" "$REVISION/${RUN[0]##*/}"
  ln -sTnfr -- "$REVISION" "$LINK"
  mv --force --no-target-directory -- "$LINK" "$DST"
  ;;
*)
  set -x
  exit 2
  ;;
esac
