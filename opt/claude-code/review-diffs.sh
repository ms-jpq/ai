#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O globstar

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

DIFFS=("$SESSION_DIR"/*.old.*)
FIRST=1
for OLD in "${DIFFS[@]}"; do
  NEW="${OLD/.old./.new.}"

  SPLIT=(split-window)
  if ((FIRST)); then
    FIRST=0
    SPLIT=(new-window -a)
  fi
  tmux "${SPLIT[@]}" -c "$SESSION_DIR" -- nvim -d -- "$OLD" "$NEW"
done
