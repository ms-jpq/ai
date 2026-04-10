#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

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
  SELF="$(realpath -- "$0")"
  BASE="${SELF%/*}"
  DIFF_DIR="$(realpath -- "$BASE/../../var/deltas")"
  cd -- "$DIFF_DIR"

  ARGV=(
    find .
    -mindepth 1
    -maxdepth 1
    -type d
    -print0
  )
  "${ARGV[@]}" | ~/.config/zsh/libexec/fzf-lr.sh "$0" "$*"
  ;;
esac
