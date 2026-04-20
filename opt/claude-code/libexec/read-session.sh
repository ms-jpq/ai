#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"

if ! SESSION_ID="$("$BASE/which-session.sh")"; then
  exit
fi

ROOT="$(realpath -- "$BASE/../../..")"
MARKDOWN="$ROOT/var/sessions/$SESSION_ID.md"

if ! [[ -f $MARKDOWN ]]; then
  exec -- tmux display-message -- '🐶'
fi

if [[ -v RECUR ]]; then
  "$ROOT/node_modules/.bin/prettier" --write --log-level=warn -- "$MARKDOWN"
  exec -- printf -- '\n' >> "$MARKDOWN"
fi

RECUR=1 flock "$MARKDOWN" "$0"

# shellcheck disable=SC2154
tmux new-window -a -c "$PWD" -- nvim -M -c "norm! G" -c "?\V# >>>" -c "norm! zz" -- "$MARKDOWN"
