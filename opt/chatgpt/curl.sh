#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl
  --config "${0%/*}/../../etc/curlrc"
  --header 'Content-Type: application/json'
  --no-progress-meter
  "$@"
)

exec -- "${CURL[@]}"
