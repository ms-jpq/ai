#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
TITLE="$(jq --raw-output '.title // "Claude Code"' <<< "$JSON")"
MESSAGE="$(jq --raw-output '.message' <<< "$JSON")"

exec -- ~/.local/libexec/notify.kitty.sh /tmp/kitty.*.sock "$TITLE" "$MESSAGE"
