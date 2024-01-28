#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

mkdir -v -p -- "${*%/*}" >&2
touch -- "$*"
# shellcheck disable=SC2154
exec -- $EDITOR "$*"
