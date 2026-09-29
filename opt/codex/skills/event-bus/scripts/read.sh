#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ROOT="$(git rev-parse --show-toplevel 2> /dev/null)"; then
  INBOX="$ROOT/.notes/events"
else
  INBOX="$PWD/.notes/events"
fi

mkdir -p -- "$INBOX"
exec -- flock -- "$INBOX" find "$INBOX" -type f -exec cat -- '{}' ';' -delete
