#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

TEE=(tree --fromfile --noreport . -F)
while (($#)); do
  case "$1" in
  --plain)
    TEE=(tee)
    shift -- 1
    ;;
  --)
    shift -- 1
    break
    ;;
  -*)
    set -x
    exit 2
    ;;
  *)
    break
    ;;
  esac
done

DEPTH="${2:-67}"
if (($# < 1 || $# > 2)) || [[ $DEPTH != +([0-9]) ]]; then
  set -x
  exit 2
fi
DEPTH=$((10#$DEPTH))
"${0%/*}/traversal.sh" data/wants "$DEPTH" "$1" | while IFS= read -r -d '' CHAIN && IFS= read -r -d '' _; do
  if [[ $CHAIN == */* ]]; then
    printf -- '%s\n' "${CHAIN#*/}"
  fi
done | "${TEE[@]}"
