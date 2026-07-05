#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"

TOOL="$(jq -e --raw-output '.tool_name | select(IN("Bash", "apply_patch"))' <<< "$JSON")"
COMMAND="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"

exec -- "${0%/*}/parse-hook-paths/$TOOL.awk" <<< "$COMMAND"
