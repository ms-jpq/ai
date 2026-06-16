#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

MODE="$1"
SRC="$2"
if [[ -d $SRC ]]; then
  TOP="$(git -C "$SRC" rev-parse --show-toplevel 2> /dev/null)" || TOP="$(realpath -- "$SRC")"
  NAME="${TOP##*/}"
else
  BASE="${SRC%.md}"
  NAME="${BASE##*/}"
fi

case "$MODE" in
name)
  printf -- '%s' "$NAME"
  ;;
path)
  COMMON="$(git rev-parse --path-format=absolute --git-common-dir)"
  ROOT="${COMMON%/.git}"
  printf -- '%s' "$ROOT/.notes/tasks/$NAME.md"
  ;;
*)
  set -x
  exit 2
  ;;
esac
