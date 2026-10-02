#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SERVICE="${PWD%/log}"
JOB="${SERVICE%/instances/*}"
LOGS="$JOB/../../log/${JOB##*/}"

mkdir -p -- "$LOGS"
exec -- s6-log -b -l 0 -d "$(< ./notification-fd)" -- T "p${JOB##*/}@${SERVICE##*/}" 1 >> "$LOGS/${SERVICE##*/}.log"
