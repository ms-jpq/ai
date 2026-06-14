#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

NAME="$1"

HR=~/.local/libexec/hr.sh

COMMON="$(git rev-parse --path-format=absolute --git-common-dir)"
ROOT="${COMMON%/.git}"
SESSION="worktree/${ROOT##*/}/$NAME"
SESSION="${SESSION//[.:]/-}"
NOTES="$ROOT/.notes/worktree/$NAME"

~/.local/libexec/preview.sh "$NOTES"

if tmux has-session -t "=$SESSION" 2> /dev/null; then
  printf -- '\n'
  printf -- '\n'
  "$HR"
  "$HR"
  printf -- '\n'
  printf -- '\n'

  exec -- tmux capture-pane -e -p -t "$SESSION"
fi
