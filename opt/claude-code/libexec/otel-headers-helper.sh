#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# shellcheck disable=SC2154
TOKEN="$(jq -e --raw-input --join-output '@base64' <<< ":")"

tee <<- JSON
{"Authorization": "Basic $TOKEN"}
JSON
