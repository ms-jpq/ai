#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
SESSION="$(jq --raw-output '.session_id' <<< "$JSON")"

STORE="$PWD/.llm"
MD="$STORE/$SESSION.md"

mkdir -p -- "$STORE"
jq --raw-output '["# >>> assistant <<<", "", .last_assistant_message, "", "---"][]' <<< "$JSON" >> "$MD"

printf -- '%s' '{}'
