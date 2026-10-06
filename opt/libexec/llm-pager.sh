#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STREAMING="$1"
shift -- 1

SED=(
  sed
  -E -n -u
  -e '/^\{/p'
  -e '/^data:/s/^data:[[:space:]]+(\{.*)/\1/gp'
)

{
  printf -- '\n'
  hr.sh '>'
  printf -- '\n'
} >&2
"${SED[@]}" | "$@" | md-pager.sh "$STREAMING" | tee -- /dev/stderr
printf -- '\n' >&2
{
  printf -- '\n'
  hr.sh '<'
  printf -- '\n'
} >&2
