#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SRC="$1"
if [[ -d $SRC ]]; then
  TOP="$(git -C "$SRC" rev-parse --show-toplevel 2> /dev/null)" || TOP="$(realpath -- "$SRC")"
  COMMON="$(git -C "$SRC" rev-parse --path-format=absolute --git-common-dir 2> /dev/null)" || COMMON=""
  if [[ $TOP == "${COMMON%/.git}" ]]; then
    NAME=""
  else
    NAME="${TOP##*/}"
  fi
else
  BASE="${SRC%.md}"
  NAME="${BASE##*/}"
fi

printf -- '%s' "$NAME"
