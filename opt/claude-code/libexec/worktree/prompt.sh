#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ACTION="$1"
PROMPT="$2"
SUM="${PROMPT%.md}.sum"

case "$ACTION" in
seal)
  b2sum -- "$PROMPT" | cut -d ' ' -f 1 > "$SUM"
  ;;
drifted)
  if ! [[ -f $SUM && -f $PROMPT ]]; then
    exit 1
  fi
  HASH="$(b2sum -- "$PROMPT" | cut -d ' ' -f 1)"
  if [[ $HASH == "$(< "$SUM")" ]]; then
    exit 1
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
