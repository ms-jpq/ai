#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v __CLAUDE_SESSION_ID ]]; then
  set -x
  exit 2
fi

ROOT="${0%/*}/.."
MARKDOWN="./.markdown/$__CLAUDE_SESSION_ID.md"
flock "$MARKDOWN" "$ROOT/node_modules/.bin/prettier" --write -- "$MARKDOWN"

# shellcheck disable=SC2094
flock "$MARKDOWN" printf -- '\n' >> "$MARKDOWN"

# shellcheck disable=2154
exec -- tmux new-window -a -c "$PWD" -- nvim -c "norm! ggGMzz" -- "$MARKDOWN"
