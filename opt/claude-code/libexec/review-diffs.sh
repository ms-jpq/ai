#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O globstar

set -o pipefail

BASE="${0%/*}"

if ! SESSION_ID="$("$BASE/which-session.sh")"; then
  exit
fi

SESSION_DIR="$(realpath --no-symlinks -- "$BASE/../../../var/sessions")/$SESSION_ID"
mkdir -p -- "$SESSION_DIR"

DELTA="$SESSION_DIR/$SESSION_ID.delta.json"
NAME="$SESSION_ID.delta.json"
DIFFS=("$SESSION_DIR"/!("$NAME"))

if ! [[ -f $DELTA ]] || ((${#DIFFS[@]} == 0)); then
  exec -- tmux display-message -- '🫧'
fi

CWD="$(jq -e --raw-output '.cwd' < "$DELTA")"
OLD="$(jq -e --raw-output '.tool_input.file_path' < "$DELTA")"

SPLIT=(new-window -a)
for NEW in "${DIFFS[@]}"; do
  tmux "${SPLIT[@]}" -c "$CWD" -- nvim -d -- "$OLD" "$NEW"
  SPLIT=(split-window)
done

exec -- tmux select-layout tiled
