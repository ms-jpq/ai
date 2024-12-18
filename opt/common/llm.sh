#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
DIR="${BASE%/*}"
PATH="$DIR:$PATH"
DIRS=(
  "$DIR"
  "$DIR/../chatty"
  "$DIR/../ollama"
  "$DIR/../anthropic"
  "$DIR/../openai"
  "$DIR/../perplexica"
)

PROGRAM="${1:-""}"
case "$PROGRAM" in
'')
  exec -- find "${DIRS[@]}" -name 'llm-*.sh' -exec basename -- '{}' ';'
  ;;
*)
  shift -- 1
  set -a
  # shellcheck disable=SC1091
  source -- "$DIR/../../.env"
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
