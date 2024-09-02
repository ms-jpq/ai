#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
DIR="${BASE%/*}"
PATH="$DIR/../../libexec:$DIR:$PATH"

PROGRAM="${1:-""}"
case "$PROGRAM" in
'')
  exec -- find "$DIR" -name 'llm-*.sh' -exec basename -- '{}' ';'
  ;;
*)
  shift -- 1
  export -- PATHMOD=1
  exec -- "${BASE%'.sh'}-$PROGRAM.sh" "$@"
  ;;
esac
