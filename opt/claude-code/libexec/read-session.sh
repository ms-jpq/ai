#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"

if ! SESSION_ID="$("$BASE/which-session.sh")"; then
  exit
fi

MARKDOWN="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.var/sessions/$SESSION_ID.md"

if ! [[ -f $MARKDOWN ]]; then
  exec -- tmux display-message -- '🐶'
fi

if [[ -v RECUR ]]; then
  if command -v -- prettier > /dev/null; then
    markdown-fmt --tabsize=2 --filename _.md < "$MARKDOWN" | sponge -- "$MARKDOWN"
  fi
  exec -- printf -- '\n' >> "$MARKDOWN"
fi

RECUR=1 ~/.local/libexec/flock.sh "$MARKDOWN" "$0"

# shellcheck disable=SC2154
exec -- tmux new-window -a -c '#{pane_current_path}' -- nvim -M -c "norm! G" -c "/\V# >>>" -c "norm! N" -c "norm! zz" -- "$MARKDOWN"
