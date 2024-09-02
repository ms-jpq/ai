#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

NAME="$1"
COLOUR="$2"
shift -- 2

BASE=${0%/*}
EXT='txt'
BANK="$BASE/../etc/prompts"
mkdir -v -p -- "$BANK" >&2

case "${1:-""}" in
'')
  exec -- "$BASE/readline.sh" "$COLOUR" "$NAME"
  ;;
-)
  shift -- 1
  printf -- '%s' "$*"
  ;;
@)
  shift -- 1
  cd -- "$BANK"
  TXTS=(*."$EXT")
  printf -v PREVIEW -- '%q ' cat --
  TXT="$(printf -- '%s\0' "${TXTS[@]}" | fzf --read0 --preview="$PREVIEW {}" --query="$*")"
  exec -- cat -- "$TXT"
  ;;
*)
  INPUT=(
    "$*"
    "$*.$EXT"
    "$BANK/$*.$EXT"
  )
  for TXT in "${INPUT[@]}"; do
    if [[ -f $TXT ]]; then
      exec -- cat -- "$TXT"
    fi
  done
  set -x
  exit 1
  ;;
esac
