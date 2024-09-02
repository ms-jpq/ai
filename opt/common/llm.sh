#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
DIR="${BASE%/*}"
PATH="$DIR/../../libexec:$PATH"
DIRS=("$DIR" "$DIR/../anthropic" "$DIR/../openai")

PROGRAM="${1:-""}"
case "$PROGRAM" in
'')
  exec -- find "${DIRS[@]}" -name 'llm-*.sh' -exec basename -- '{}' ';'
  ;;
*)
  shift -- 1
  for DIR in "${DIRS[@]}"; do
    SH="$DIR/llm-$PROGRAM.sh"
    if [[ -x $SH ]]; then
      PATH="$DIR:$PATH"
      exec -- "$SH" "$@"
    fi
  done
  set -x
  exit 127
  ;;
esac
