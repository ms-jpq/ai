#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v __CLAUDE_SESSION_ID ]] || ! [[ -v TMUX_PANE ]]; then
  set -x
  exit 2
fi

ROOT="$(realpath -- "${0%/*}")/../../.."
MARKDOWN="$ROOT/var/sessions/$__CLAUDE_SESSION_ID.md"

if [[ -v RECUR ]]; then
  "$ROOT/node_modules/.bin/prettier" --write --log-level=warn -- "$MARKDOWN"
  exec -- printf -- '\n' >> "$MARKDOWN"
fi

RECUR=1 flock "$MARKDOWN" "$0"

# shellcheck disable=2154
exec -- tmux new-window -a -c "$PWD" -- nvim -M -c "norm! ggGMzz" -- "$MARKDOWN"
