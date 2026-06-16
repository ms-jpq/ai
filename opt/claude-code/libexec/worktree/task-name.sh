#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SRC="$1"
COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null)" || COMMON=""
ROOT="${COMMON%/.git}"

if [[ $SRC != @(.|..|*/*) && -n $ROOT && -d "$ROOT/.notes/worktrees/$SRC" ]]; then
  NAME="$SRC"
elif [[ -d $SRC ]]; then
  TOP="$(git -C "$SRC" rev-parse --show-toplevel)"
  NAME="${TOP##*/}"
else
  BASE="${SRC%.md}"
  NAME="${BASE##*/}"
fi

printf -- '%s' "$NAME"
