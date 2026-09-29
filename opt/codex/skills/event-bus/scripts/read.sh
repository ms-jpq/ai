#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ROOT="$(git rev-parse --show-toplevel 2> /dev/null)"; then
  INBOX="${1:-$ROOT/.notes/events}"
else
  INBOX="${1:-$PWD/.notes/events}"
fi

mkdir -p -- "$INBOX"
if grep --recursive --with-filename --line-number -- . "$INBOX"; then
  exit 0
else
  STATUS=$?
  if ((STATUS == 1)); then
    exit 0
  fi
  exit "$STATUS"
fi
