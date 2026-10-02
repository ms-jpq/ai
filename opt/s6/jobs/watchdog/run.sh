#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

mapfile -t PARENT < "${0%/*}/parent"
P_PID="${PARENT[0]}" P_STARTED="${PARENT[1]}"

if ! STARTED="$(LC_ALL=C.UTF-8 ps -p "$P_PID" -o lstart=)" || [[ $STARTED != "$P_STARTED" ]]; then
  exec -- s6-svscanctl -t -- "${0%/*}/../../../.."
fi
