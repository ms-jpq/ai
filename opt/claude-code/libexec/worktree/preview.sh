#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

ROOT="$1"
NAME="$2"

SESSION="$("$SELF/pool.sh" session "$NAME")"
NOTES="$ROOT/.notes/worktree/$NAME"

~/.local/libexec/preview.sh "$NOTES"

if tmux has-session -t "=$SESSION" 2> /dev/null; then
  printf -- '\n\n'
  ~/.local/libexec/hr.sh
  ~/.local/libexec/hr.sh
  printf -- '\n\n'

  exec -- tmux capture-pane -e -p -t "$SESSION"
fi
