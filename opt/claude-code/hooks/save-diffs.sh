#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

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

  NEW="${ENTRY_DIR}/${BASENAME}"
  mkdir -p -- "$ENTRY_DIR"
  jq --sort-keys '.' <<< "$JSON" > "$ENTRY_DIR/$SESSION_ID.delta.json"

  case "$TOOL_NAME" in
  Edit)
    exec -- "$BASE/../libexec/edit-replace.jq" --raw-output --join-output --rawfile original "$ORIGINAL" <<< "$JSON" > "$NEW"
    ;;
  Write)
    exec -- jq -e --raw-output --join-output '.tool_input.content' <<< "$JSON" > "$NEW"
    ;;
  *)
    set -x
    exit 2
    ;;
  esac
  ;;
PostToolUse | PostToolUseFailure)
  find "$ENTRY_DIR" -mindepth 1 -delete
  ;;
*)
  set -x
  exit 2
  ;;
esac
