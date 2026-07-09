#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SRC="$1"
DST="$2"

mkdir -p -- "${DST%/*}"
if [[ -L $DST ]]; then
  rm -f -- "$DST"
fi
touch -- "$DST"

# shellcheck disable=SC2016
GENERATOR=(
  sed -E -n
  -e 's|^[[:space:]]*(#:schema)[[:space:]].*$|/^[[:space:]]*#:schema[[:space:]]/d|p'
  -e '/^[[:space:]]*\[/,$d'
  -e 's|^[[:space:]]*([A-Za-z0-9_.-]+)[[:space:]]*=.*$|/^[[:space:]]*\1[[:space:]]*=/d|p'
  -- "$SRC"

)

LS="$("${GENERATOR[@]}")"
readarray -t -- LINES < <(printf -- '%s' "$LS")

ARGV=(sed -E)
for LINE in "${LINES[@]}"; do
  ARGV+=(-e "$LINE")
done
ARGV+=(-e '/[^[:space:]]/,$!d')

{
  cat -- "$SRC"
  printf -- '\n\n'
  "${ARGV[@]}" -- "$DST"
} | sponge -- "$DST"
