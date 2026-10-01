#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${S67_WORKSPACE?}"
: "${S67_TIMEOUT?}"

JOB="$PWD/data/job"

exec 2>&1
exec -- env -C "$S67_WORKSPACE" -- timeout --foreground --kill-after=5s "$S67_TIMEOUT" nice -n 19 -- "$JOB" "$@"
