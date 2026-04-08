#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v TMUX_PANE ]]; then
  exit 1
fi

PROJ_DIR="$1"
if PROJ_DIR="$(~/.local/libexec/dnif.sh "$PROJ_DIR" .claude)"; then
  :
fi
HASHED="$(md5 <<< "$PROJ_DIR")"

INFO="$(tmux display-message -p '#{session_name}:#{window_index}:#{pane_index}')"
INDEX="${0%/*}/../../../var/sessions/$HASHED.$INFO"
printf -- '%s' "$INDEX"
