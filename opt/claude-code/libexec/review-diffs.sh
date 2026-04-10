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

DELTAS="$(realpath --no-symlinks -- "${0%/*}/../../../var/deltas")"
SESSION_DIR="$DELTAS/$SESSION_ID"
mkdir -p -- "$SESSION_DIR"

NAME="$SESSION_ID.delta.json"
DIFFS=("$SESSION_DIR"/!("$NAME"))

if ((${#DIFFS[@]} == 0)); then
  RELATIVE="$(realpath --relative-base="$HOME" -- "$SESSION_DIR")"
  exec -- tmux display-message -- "🫧 ~/$RELATIVE"
fi

CWD="$(jq -e --raw-output '.cwd' < "$SESSION_DIR/$SESSION_ID.delta.json")"
OLD="$(jq -e --raw-output '.tool_input.file_path' < "$SESSION_DIR/$SESSION_ID.delta.json")"

SPLIT=(new-window -a)
for NEW in "${DIFFS[@]}"; do
  tmux "${SPLIT[@]}" -c "$CWD" -- nvim -d -- "$OLD" "$NEW"
  SPLIT=(split-window)
done
