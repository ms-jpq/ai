#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SRC="$1"
DST="$2"
DST_DIR="${DST%/*}"
DST_DIR="$(realpath -- "$DST_DIR")"

mkdir -p -- "$DST_DIR"
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

MCJ='model_catalog_json'
ARGV=(sed -E)
for LINE in "${LINES[@]}"; do
  ARGV+=(-e "$LINE")
done
ARGV+=(-e "/^[[:space:]]*${MCJ}[[:space:]]*=/d")
ARGV+=(-e '/[^[:space:]]/,$!d')

{
  cat -- "$SRC"
  printf -- '%s = "%s"\n' "$MCJ" "$DST_DIR/model_catalog.json"
  printf -- '\n\n'
  "${ARGV[@]}" -- "$DST"
} | sponge -- "$DST"
