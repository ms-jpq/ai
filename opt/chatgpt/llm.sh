#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
DIR="${BASE%/*}"
PATH="$DIR/../../libexec:$DIR:$PATH"

NETRC="$HOME/.netrc"
if ! grep -F -- 'openai.com' "$NETRC" >/dev/null 2>&1; then
  tee -- "$NETRC" <<-EOF
machine api.openai.com
password
EOF
  edit.sh "$NETRC"
  chmod 0600 "$NETRC"
fi

PROGRAM="${1:-""}"
case "$PROGRAM" in
token)
  edit.sh
  chmod 0600 "$NETRC"
  ;;
'')
  exec -- find "$DIR" -name 'llm-*.sh' -exec basename -- '{}' ';'
  ;;
*)
  shift -- 1
  exec -- "${BASE%'.sh'}-$PROGRAM.sh" "$@"
  ;;
esac
