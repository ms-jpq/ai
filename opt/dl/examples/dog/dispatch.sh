#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

exec -- ln -sTnf -- "$1/inbox" "$1/launch/recurring/-"
