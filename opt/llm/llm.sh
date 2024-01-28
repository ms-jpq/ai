#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"

if ! (($#)); then
  printf -- 'llm %s\n' request token
  for F in "$BASE-"*; do
    F="${F##*/}"
    F="${F/-/ }"
    if [[ "$F" != 'llm' ]]; then
      printf -- '%s\n' "$F"
    fi
  done
  exit
fi

NETRC="$HOME/.netrc"
edit() {
  mkdir -v -p -- "${NETRC%/*}"
  touch -- "$NETRC"
  chmod 0600 "$NETRC"
  # shellcheck disable=SC2154
  exec -- $EDITOR "$NETRC"
}

if ! grep -F -- 'openai.com' "$NETRC" >/dev/null 2>&1; then
  tee -- "$NETRC" <<-EOF
machine api.openai.com
password
EOF
  edit
fi

PROGRAM="${1:-""}"
case "$PROGRAM" in
r | request)
  shift -- 1
  ;;
t | token)
  edit
  ;;
*)
  shift -- 1
  exec -- "${BASE%'.sh'}-$PROGRAM.sh" "$@"
  ;;
esac
