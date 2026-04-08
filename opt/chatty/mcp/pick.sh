#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="${0%/*}/../../claude-code/mcp.json"
SERVERS="$(jq --exit-status --raw-input --null-input --compact-output '[inputs]')"

read -r -d '' -- JQ <<- 'JQ' || true
[to_entries[] | .value.type = "url" | select(.key | IN($servers[]))] | from_entries
JQ

jq --argjson servers "$SERVERS" "$JQ" < "$JSON" | envsubst
