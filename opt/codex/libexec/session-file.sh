#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v TMUX_PANE ]]; then
  exit 1
fi

INFO="$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}:#{pane_index}')"
HASH="$(b3sum <<< "$1")"
INDEX="$HOME/.local/opt/ai/var/sessions/${HASH%% *}.$INFO"
printf -- '%s' "$INDEX"
