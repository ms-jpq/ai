#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
_CMD_LINE="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"
