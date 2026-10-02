#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

printf -- '%s' "$$" > ./data/.pgid
exec -- s6-envdir -- ./env ./data/runner.sh "$@"
