#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
DIR="${BASE%/*}"
ROOT="$DIR/../.."
CURLHOME="$ROOT/libexec"
PATH="$CURLHOME:$PATH"
DIRS=("$DIR" "$DIR/../anthropic" "$DIR/../openai")

PROGRAM="${1:-""}"
case "$PROGRAM" in
'')
  exec -- find "${DIRS[@]}" -name 'llm-*.sh' -exec basename -- '{}' ';'
  ;;
*)
  shift -- 1
  set -a
  # shellcheck disable=SC1091
  source -- "$ROOT/.env"
  set +a

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
