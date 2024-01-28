#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

COLOUR="$1"
shift -- 1

HIST="${0%/*}/../var/readline"
mkdir -v -p -- "$HIST" >&2

ARGV=(
  rlwrap
  --one-shot
  --history-no-dupes 2
  --substitute-prompt '>: '
  --prompt-colour="$COLOUR"
  --history-filename "$HIST/$*.history"
  -- tee
)

exec -- "${ARGV[@]}"
