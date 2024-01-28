#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

COLOUR="$1"
shift -- 1
NAME="$*"

HIST="${0%/*}/../var/readline"
mkdir -v -p -- "$HIST" >&2

ARGV=(
  rlwrap
  --one-shot
  --history-no-dupes 2
  --substitute-prompt '>: '
  --prompt-colour="$COLOUR"
  --history-filename "$HIST/$NAME.history"
  -- sed -E -l -e 's/^[[:space:]]+|[[:space:]]+$//g'
)

exec -- "${ARGV[@]}"
