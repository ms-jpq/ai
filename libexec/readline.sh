#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

COLOUR="$1"
shift -- 1
NAME="$*"

BASE="${0%/*}/.."
HIST="$BASE/var/readline"
mkdir -v -p -- "$HIST" >&2

ARGV=(
  rlwrap
  --one-shot
  --history-no-dupes 2
  --substitute-prompt '>: '
  --prompt-colour="$COLOUR"
  --history-filename "$HIST/$NAME.history"
  -- sed -E -u -e 's/^[[:space:]]+|[[:space:]]+$//g'
)

export -- INPUTRC="$BASE/etc/inputrc"
exec -- "${ARGV[@]}"
