#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SRC="$1"
DST="$2"

case "${RECUR:-}" in
'')
  SRC="$(realpath -- "$SRC")"
  DST="${DST%/}"
  PARENT="$(dirname -- "$DST")"
  PARENT="$(realpath -- "$PARENT")"
  STAGING="$PARENT/.${DST##*/}"
  if [[ $STAGING/ == "$SRC/"* ]]; then
    set -x
    exit 2
  fi
  mkdir -- "$STAGING"
  trap 'rm -fr -- "$STAGING"' EXIT
  rsync --archive -- "$SRC/" "$STAGING/" >&2
  find "$STAGING" -type l -printf '%P\0' | RECUR=1 xargs --null --no-run-if-empty --max-procs=0 -I '{}' -- "$0" "$SRC/{}" "$STAGING/{}" "$SRC"
  trap - EXIT
  printf -- '%s' "$STAGING"
  ;;
1)
  TARGET="$(readlink -- "$DST")"
  ORIGIN="${SRC%/*}"
  if [[ $TARGET == /* ]]; then
    ORIGIN=/
    TARGET="${TARGET#/}"
  fi
  RESOLVED="$(realpath --canonicalize-missing --no-symlinks -- "$ORIGIN/$TARGET")"
  if [[ $RESOLVED == "$3" ]] || [[ $RESOLVED == "$3/"* ]]; then
    if [[ $ORIGIN != / ]]; then
      exit
    fi
    TARGET="$(realpath --canonicalize-missing --no-symlinks --relative-to="${SRC%/*}" -- "$RESOLVED")"
    exec -- ln -sTnf -- "$TARGET" "$DST"
  fi
  PREFIX="$(realpath --canonicalize-missing --no-symlinks --relative-to="${DST%/*}" -- "$ORIGIN")"
  ln -sTnf -- "$PREFIX/$TARGET" "$DST"
  ;;
*)
  set -x
  exit 2
  ;;
esac
