#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

NAME="$1"
COLOUR="$2"
shift -- 2

BASE=${0%/*}
EXT='txt'
BANK="$BASE/../etc/prompts"
mkdir -v -p -- "$BANK" >&2

case "$*" in
'')
  exec -- "$BASE/readline.sh" "$COLOUR" "$NAME"
  ;;
-)
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
      exec -- cat -- "$TXT"
    fi
  done
  ;;
esac

if ! [[ -t 0 ]]; then
  printf -- '%s' "$*"
else
  set -x
  exit 1
fi
