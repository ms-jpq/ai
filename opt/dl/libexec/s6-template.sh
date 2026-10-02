#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

SELF="$(realpath -- "$0")"
SRC="$(realpath -- "$1")"
DST="${2%/}"

case "${RECUR:-}" in
'')
  mkdir -p -- "$DST"
  find "$SRC" -mindepth 1 -maxdepth 1 '(' -type d -o -type l ')' ! -name '.*' -printf '%f\0' | RECUR=1 xargs --null --no-run-if-empty --max-procs=0 -I '{}' -- "$SELF" "$SRC/{}" "$DST/{}"
  ;;
1)
  RUN=("$SRC"/run.*)
  if ((${#RUN[@]} != 1)) || ! [[ -f ${RUN[*]} && -x ${RUN[*]} ]]; then
    set -x
    exit 2
  fi

  PARENT="$(dirname -- "$DST")"
  mkdir -p -- "$PARENT"

  STAGING="$(mktemp -d -- "$PARENT/.${DST##*/}.XXXXXX")"
  trap 'rm -f -- "$STAGING.link"' EXIT
  rsync --archive --include='/env/***' --include='/data/***' --exclude='/*' -- "$SRC/" "$STAGING/"
  cp --preserve=mode,timestamps -- "${RUN[*]}" "$STAGING/${RUN[0]##*/}"
  ln -s -- "${STAGING##*/}" "$STAGING.link"
  mv --force --no-target-directory -- "$STAGING.link" "$DST"
  ;;
*)
  set -x
  exit 2
  ;;
esac
