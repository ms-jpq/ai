#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

INBOX="$PWD/.notes/events"

mkdir -p -- "$INBOX"
exec -- flock -- "$INBOX" find "$INBOX" -type f -exec cat -- '{}' ';' -delete
