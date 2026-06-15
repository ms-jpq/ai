#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

ROOT="$1"
NAME="$2"

NOTES="$ROOT/.notes/worktree/$NAME"

~/.local/libexec/preview.sh "$NOTES"

HISTORY="$NOTES/HISTORY.md"
if [[ -e $HISTORY ]]; then
  printf -- '\n\n'
  ~/.local/libexec/hr.sh
  ~/.local/libexec/hr.sh
  printf -- '\n\n'

  tail -n 99 -- "$HISTORY"
fi
