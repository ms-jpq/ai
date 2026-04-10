#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
BASE="${SELF%/*}"
DIFF_DIR="$(realpath -- "$BASE/../../var/deltas")"

case "${SCRIPT_MODE:-""}" in
preview)
  CWD="$(tr -d '\0')"
  cd -- "$CWD"
  exec -- delta -- old* new*
  ;;
execute)
  CWD="$(tr -d '\0')"
  cd -- "$CWD"
  exec -- nvim -d -- old* new*
  ;;
*)

  ARGV=(
    find "$DIFF_DIR"
    -mindepth 2
    -name 'cwd.txt'
    -execdir cat -- '{}' ';'
  )
  "${ARGV[@]}" | ~/.config/zsh/libexec/fzf-lr.sh "$0" "$*"
  ;;
esac
