#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

P_PID="$1"
P_STARTED="$(< "${0%/*}/../../../data/.s9/launch/$P_PID")"

if ! STARTED="$(LC_ALL=C.UTF-8 ps -p "$P_PID" -o lstart=)" || [[ $STARTED != "$P_STARTED" ]]; then
  exec -- s6-svscanctl -t -- "${0%/*}/../../../.."
fi
