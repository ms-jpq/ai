#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STREAMING="$1"
TEE="$2"
shift -- 2

hr() {
  printf -- '\n'
  hr.sh "$@"
  printf -- '\n'
}

SED=(
  sed
  -E -n -u
  -e '/^\{/p'
  -e '/^data:/s/^data:[[:space:]]+(\{.*)/\1/gp'
)

{
  hr '>'
  "${SED[@]}" | "$@" | md-pager.sh "$STREAMING" "$TEE"
  printf -- '\n'
  hr '<'
} >&2
