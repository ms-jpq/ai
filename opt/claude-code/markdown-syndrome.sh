#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v __CLAUDE_SESSION_ID ]]; then
  set -x
  exit 2
fi

# shellcheck disable=2154
tmux new-window -a -c "$PWD" -- nvim -c "norm! ggGMzz" -- "./.markdown/$__CLAUDE_SESSION_ID.md"
