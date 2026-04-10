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
  ORIGINAL="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"
  BASENAME="${ORIGINAL##*/}"
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
  jq --sort-keys '.' <<< "$JSON" > "${ENTRY_DIR}/${STEM}.json"

  case "$TOOL_NAME" in
  Edit)
    if ! [[ -f $OLD ]]; then
      cp -- "$ORIGINAL" "$OLD"
    else
      ORIGINAL="$OLD"
    fi

    if jq -e '.tool_input.replace_all' <<< "$JSON" > /dev/null; then
      read -r -d '' -- JQ <<- 'JQ' || true
.tool_input as {old_string: $old, new_string: $new}
| $original | split($old) | join($new)
JQ
    else
      read -r -d '' -- JQ <<- 'JQ' || true
.tool_input as {old_string: $old, new_string: $new}
| ($original | index($old)) as $i
| if $i then $original[:$i] + $new + $original[($i + ($old | length)):] else $original end
JQ
    fi

    exec -- jq -e --raw-output --join-output --rawfile original "$ORIGINAL" "$JQ" <<< "$JSON" > "$NEW"
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
