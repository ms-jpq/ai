#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v TMUX_PANE ]]; then
  exit 1
fi

INFO="$(tmux display-message -p '#{session_name}:#{window_index}:#{pane_index}')"
INDEX="${0%/*}/../../../var/sessions/$(md5 <<< "$1").$INFO"
printf -- '%s' "$INDEX"
