#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

COLOUR="$1"
shift -- 1
NAME="$*"

BASE="${0%/*}"
HIST="$HOME/.local/state/ai/readline"
mkdir -v -p -- "$HIST" >&2

ARGV=(
  rlwrap
  --one-shot
  --no-children
  --multi-line
  --multi-line-ext '.md'
  --extra-char-after-completion $'\n'
  --history-no-dupes 2
  --substitute-prompt '>: '
  --prompt-colour="$COLOUR"
  --history-filename "$HIST/$NAME.history"
  -- sed -E -u
  -e '1s/^[[:space:]]+//g'
  -e 's/[[:space:]]+$//g'
)

RLWRAP_EDITOR="$BASE/rlwrap-editor.sh" INPUTRC="$BASE/inputrc" exec -- "${ARGV[@]}"
