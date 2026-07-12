#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASENAME="${1##*/}"
shift -- 1

for PAT in "$@"; do
  # shellcheck disable=SC2254
  case "$BASENAME" in
  $PAT)
    exit 0
    ;;
  *)
    ;;
  esac
done

exit 1
