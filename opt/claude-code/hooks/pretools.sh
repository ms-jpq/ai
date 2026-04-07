#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
COMMAND="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"
