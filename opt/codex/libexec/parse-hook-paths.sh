#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
PREFIX="${0%/*}/parse-hook-paths"

READ_TOO=0
if (($#)); then
  case "$1" in
  --read-too)
    READ_TOO=1
    shift -- 1
    ;;
  *)
    set -x
    exit 2
    ;;
  esac
fi
if (($#)); then
  set -x
  exit 2
fi

TOOL="$(jq -e --raw-output '.tool_name | select(IN("Bash", "apply_patch"))' <<< "$JSON")"
COMMAND="$(jq -e --raw-output '.tool_input.command' <<< "$JSON")"

case "$TOOL" in
apply_patch)
  ARGV=("$PREFIX/apply_patch.awk" -v "READ_TOO=$READ_TOO")
  ;;
Bash)
  ARGV=("$PREFIX/bash.py" "$READ_TOO")
  ;;
*)
  set -x
  exit 1
  ;;
esac

exec -- "${ARGV[@]}" <<< "$COMMAND"
