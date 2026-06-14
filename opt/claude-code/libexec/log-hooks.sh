#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SESSIONS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.var/sessions"

JSON="$(tee)"
if ! SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"; then
  exit
fi

DEBUG="$SESSIONS/$SESSION_ID.events.jsonl"
mkdir -p -- "$SESSIONS"
touch -- "$DEBUG"

# shellcheck disable=SC2094,SC2016
exec -- ~/.local/libexec/flock.sh "$DEBUG" jq -e --compact-output --arg src "$1" '.ts = (now | strftime("%H:%M:%S")) | .src = $src' <<< "$JSON" >> "$DEBUG"
