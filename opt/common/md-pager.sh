#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STREAMING="$1"

case "$STREAMING" in
0)
  COLS="$(tput -- cols)"
  COLS=$((COLS - 4))
  CLICOLOR_FORCE=1 COLORTERM=truecolor glow --config /dev/null --style pink --width "$COLS"
  ;;
1)
  bat --style plain --paging never --language markdown -- -
  ;;
2)
  tee --
  ;;
*)
  exit 1
  ;;
esac
