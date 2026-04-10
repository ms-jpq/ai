#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
SESSION_ID="$(jq --raw-output '.session_id' <<< "$JSON")"
FILE_PATH="$(jq --raw-output '.tool_input.file_path' <<< "$JSON")"
OLD_STRING="$(jq --raw-output '.tool_input.old_string' <<< "$JSON")"
NEW_STRING="$(jq --raw-output '.tool_input.new_string' <<< "$JSON")"

BASE="${0%/*}"
DIFFS="$(realpath -- "$BASE/../../../var/sessions")"

BASENAME="${FILE_PATH##*/}"
EXT="${BASENAME##*.}"
TIMESTAMP="$(date --utc '+%Y-%m-%d %H:%M:%S')"

SUFFIX=""
if [[ $EXT != "$BASENAME" ]]; then
  SUFFIX=".${EXT}"
fi

ENTRY_DIR="${DIFFS}/${SESSION_ID}/${TIMESTAMP}_${BASENAME}"
mkdir -p -- "$ENTRY_DIR"
printf -- '%s\n' "$OLD_STRING" > "${ENTRY_DIR}/old${SUFFIX}"
printf -- '%s\n' "$NEW_STRING" > "${ENTRY_DIR}/new${SUFFIX}"
printf -- '%s\n' "$FILE_PATH" > "${ENTRY_DIR}/path.txt"
