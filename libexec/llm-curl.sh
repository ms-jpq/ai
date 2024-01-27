#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

CURL=(
  curl
  --fail-early
  --location
  --header 'Content-Type: application/json'
  --no-progress-meter
  "$@"
)

if [[ -t 1 ]]; then
  "${CURL[@]}" | jq --exit-status --sort-keys
else
  exec -- "${CURL[@]}"
fi
