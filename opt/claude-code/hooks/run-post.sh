#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v RECUR ]]; then
  JSON="$(tee)"
  # "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"
  read -r -d '' -- JQ <<- 'JQ' || true
.tool_calls[]? | select(.tool_name | IN("Write", "Edit", "MultiEdit")) | .tool_input.file_path
JQ

  CTX="$(jq --raw-output0 "$JQ" <<< "$JSON" | sort -z --unique | RECUR=1 xargs -r --null -I % --max-procs=0 -- "$0" % 2>&1 || true)"
  read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolBatch",
    "additionalContext": $context
  }
}
JQ

  exec -- jq -e --null-input --arg context "$CTX" "$JQ"
fi

FILE_PATH="$*"

# shellcheck disable=SC2154,SC2094
if FMT="$("$XDG_CONFIG_HOME/nvim/libexec/fmt.sh" "$FILE_PATH" < "$FILE_PATH")"; then
  sponge -- "$FILE_PATH" <<< "$FMT"
fi

case "$FILE_PATH" in
*.sh | *.bash)
  if command -v -- shellcheck > /dev/null; then
    shellcheck --shell=bash -- "$FILE_PATH"
  fi
  ;;
*)
  ;;
esac
