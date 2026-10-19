#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# shellcheck disable=SC2069
exec -- dot -v "$@" 2>&1 > /dev/null
