#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O globstar

set -o pipefail

BASE="${0%/*}"

if ! SESSION_ID="$("$BASE/which-session.sh")"; then
  exit
fi

DELTAS="$(realpath --no-symlinks -- "$BASE/../../../var/deltas")"
SESSION_DIR="$DELTAS/$SESSION_ID"
mkdir -p -- "$SESSION_DIR"

NAME="$SESSION_ID.delta.json"
DIFFS=("$SESSION_DIR"/!("$NAME"))

if ((${#DIFFS[@]} == 0)); then
  exec -- tmux display-message -- '🫧'
fi

CWD="$(jq -e --raw-output '.cwd' < "$SESSION_DIR/$SESSION_ID.delta.json")"
OLD="$(jq -e --raw-output '.tool_input.file_path' < "$SESSION_DIR/$SESSION_ID.delta.json")"

SPLIT=(new-window -a)
for NEW in "${DIFFS[@]}"; do
  tmux "${SPLIT[@]}" -c "$CWD" -- nvim -d -- "$OLD" "$NEW"
  SPLIT=(split-window)
done

if ((${#DIFFS[@]})); then
  exec -- tmux select-layout tiled
fi
