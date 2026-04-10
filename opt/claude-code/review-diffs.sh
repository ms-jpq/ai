#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v TMUX ]]; then
  set -x
  exit 2
fi

SESSION_ID="$(tmux display-message -p '#{@claude_session}')"

if [[ -z $SESSION_ID ]]; then
  exec -- tmux display-message -- '🐶'
fi

DELTAS="${0%/*}/../../var/deltas"
SESSION_DIR="$(realpath --no-symlinks -- "$DELTAS")/$SESSION_ID"
mkdir -p -- "$SESSION_DIR"

tmux new-window -a -c "$SESSION_DIR"
