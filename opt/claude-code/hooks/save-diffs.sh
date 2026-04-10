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

  OLD="${ENTRY_DIR}/${STEM}.old${SUFFIX}"
  NEW="${ENTRY_DIR}/${STEM}.new${SUFFIX}"
  mkdir -p -- "$ENTRY_DIR"

  case "$TOOL_NAME" in
  Edit)
    cp -- "$FILE_PATH" "$OLD"

    if jq -e --raw-output '.tool_input.file_path' <<< "$JSON" > /dev/null; then
      exec -- jq -e --raw-output --join-output '.tool_input.new_string' <<< "$JSON" > "$NEW"
    fi

    read -r -d '' -- JQ <<- 'JQ' || true
.tool_input as {old_string: $old, new_string: $new} 
| ($orig | index($old)) as $i
| if $i then $orig[:$i] + $new + $orig[($i + ($old | length)):] else $orig end
JQ

    jq -e --raw-output --join-output --rawfile orig "$FILE_PATH" "$JQ" <<< "$JSON"
    ;;
  Write)
    touch -- "$OLD"
    exec -- jq -e --raw-output --join-output '.tool_input.content' <<< "$JSON" > "$NEW"
    ;;
  *)
    set -x
    exit 2
    ;;
  esac
  ;;
PostToolUse)
  find "$ENTRY_DIR" -mindepth 1 -delete > /dev/null
  ;;
*)
  set -x
  exit 2
  ;;
esac
