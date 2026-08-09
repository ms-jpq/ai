#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

TOKEN="$(jq -e --raw-input --join-output '@base64' <<< ":")"

tee <<- JSON
{"Authorization": "Basic $TOKEN"}
JSON
