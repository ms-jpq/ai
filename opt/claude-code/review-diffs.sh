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

FIRST=1
for OLD in "$SESSION_DIR"/*.old.*; do
  NEW="${OLD/.old./.new.}"
  if ((FIRST)); then
    tmux new-window -a -c "$SESSION_DIR" -- nvim -d -- "$OLD" "$NEW"
    FIRST=0
  else
    tmux split-window -c "$SESSION_DIR" -- nvim -d -- "$OLD" "$NEW"
  fi
done
