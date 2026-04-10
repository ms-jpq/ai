#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
SESSION_ID="$(jq --raw-output '.session_id' <<< "$JSON")"
TOOL_NAME="$(jq --raw-output '.tool_name' <<< "$JSON")"
FILE_PATH="$(jq --raw-output '.tool_input.file_path' <<< "$JSON")"

BASE="${0%/*}"
DIFFS="$(realpath -- "$BASE/../../../var/deltas")"

BASENAME="${FILE_PATH##*/}"
EXT="${BASENAME##*.}"

STEM="$BASENAME"
SUFFIX=""
if [[ $EXT != "$BASENAME" ]]; then
  STEM="${BASENAME%.*}"
  SUFFIX=".${EXT}"
fi

case "$TOOL_NAME" in
Edit)
  OLD_STRING="$(jq --raw-output '.tool_input.old_string' <<< "$JSON")"
  NEW_STRING="$(jq --raw-output '.tool_input.new_string' <<< "$JSON")"
  ;;
Write)
  NEW_STRING="$(jq --raw-output '.tool_input.content' <<< "$JSON")"
  OLD_STRING=""
  ;;
*)
  set -x
  exit 2
  ;;
esac

ENTRY_DIR="${DIFFS}/${SESSION_ID}"
mkdir -p -- "$ENTRY_DIR"
printf -- '%s\n' "$OLD_STRING" > "${ENTRY_DIR}/${STEM}.old${SUFFIX}"
printf -- '%s\n' "$NEW_STRING" > "${ENTRY_DIR}/${STEM}.new${SUFFIX}"
