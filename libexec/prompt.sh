#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

NAME="$1"
COLOUR="$2"
shift -- 2

BASE=${0%/*}
BANK="$BASE/../etc/prompts"
EXT='txt'

case "$*" in
-)
  exec -- "$BASE/readline.sh" "$COLOUR" "$NAME"
  ;;
!)
  cd -- "$BANK"
  TXTS=(*."$EXT")
  printf -v PREVIEW -- '%q ' cat --
  TXT="$(printf -- '%s\0' "${TXTS[@]}" | fzf --read0 --preview="$PREVIEW {}")"
  ;;
*)
  INPUT=(
    "$*"
    "$*.$EXT"
    "$BANK/$*.$EXT"
  )
  for TXT in "${INPUT[@]}"; do
    if [[ -f "$TXT" ]]; then
      break
    fi
  done
  ;;
esac

exec -- cat -- "$TXT"
