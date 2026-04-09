#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

shfmt --simplify --binary-next-line --space-redirects --indent=2 --write -- "$@"
