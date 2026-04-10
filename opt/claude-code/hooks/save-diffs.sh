#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
EVENT="$(jq -e --raw-output '.hook_event_name' <<< "$JSON")"
SESSION_ID="$(jq -e --raw-output '.session_id' <<< "$JSON")"
TOOL_NAME="$(jq -e --raw-output '.tool_name' <<< "$JSON")"

BASE="${0%/*}"
DIFFS="$(realpath -- "$BASE/../../../var/deltas")"
ENTRY_DIR="${DIFFS}/${SESSION_ID}"

case "$EVENT" in
PreToolUse)
  FILE_PATH="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"
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
    OLD_STRING="$(jq -e --raw-output '.tool_input.old_string' <<< "$JSON")"
    NEW_STRING="$(jq -e --raw-output '.tool_input.new_string' <<< "$JSON")"
    ;;
  Write)
    NEW_STRING="$(jq -e --raw-output '.tool_input.content' <<< "$JSON")"
    OLD_STRING=""
    ;;
  *)
    set -x
    exit 2
    ;;
  esac

  mkdir -p -- "$ENTRY_DIR"
  printf -- '%s\n' "$OLD_STRING" > "${ENTRY_DIR}/${STEM}.old${SUFFIX}"
  printf -- '%s\n' "$NEW_STRING" > "${ENTRY_DIR}/${STEM}.new${SUFFIX}"
  ;;
PostToolUse)
  find "$ENTRY_DIR" -mindepth 1 -delete > /dev/null
  ;;
*)
  set -x
  exit 2
  ;;
esac
