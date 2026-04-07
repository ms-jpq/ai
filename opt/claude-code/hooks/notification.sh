#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
TITLE="$(jq -e --raw-output '.title // "Claude Code"' <<< "$JSON")"
MESSAGE="$(jq -e --raw-output '.message' <<< "$JSON")"

if [[ -v SSH ]]; then
  exit
fi

exec -- ~/.local/libexec/notify.kitty.sh /tmp/kitty.*.sock "$TITLE" "$MESSAGE"
