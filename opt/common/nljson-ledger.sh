#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

PRINCIPAL="$1"
NAME="$2"
STORE="${0%/*}/../../var/history/$PRINCIPAL"

mkdir -p -- "$STORE"
if ! ((RANDOM % 16)) || [[ $NAME == '!' ]]; then
  find "$STORE" '(' -name '*.json' -empty ')' -or -name 'tmp.*' -delete
fi

case "$NAME" in
'')
  NOW="$(date -- '+%Y-%m-%d %H:%M:%S')"
  LEDGER="$STORE/$NOW.json"
  ;;
@)
  printf -v PREVIEW -- '%q ' jq --sort-keys --color-output .
  LEDGER="$(printf -- '%s\0' "$STORE"/*.json | fzf --read0 --preview="$PREVIEW {}")"
  ;;
-)
  FILES=("$STORE"/*.json)
  LEDGER="${FILES[-1]}"
  ;;
*)
  LEDGER="$STORE/$NAME.json"
  if ! [[ -f LEDGER ]]; then
    set -x
    exit 1
  fi
  ;;
esac

touch -- "$LEDGER"
printf -- '%s' "$LEDGER"
