#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STATUS="$1"
SIGNAL="$2"
INSTANCE="$3"

JOB="${PWD%/instances/*}"
JOB="${JOB##*/}"
INSTANCE_DATA='./data'
ATTEMPTS="$INSTANCE_DATA/attempt"

exec 2>&1

if [[ -n ${4:-} || -f $INSTANCE_DATA/pgid ]]; then
  PGID="${4:-$(< "$INSTANCE_DATA/pgid")}"
  rm -f -- "$INSTANCE_DATA/pgid"
  kill -KILL -- "-$PGID" 2> /dev/null || true
fi

EXIT_STATUS=0
if [[ -d $INSTANCE_DATA/recurring ]]; then
  if ((STATUS == 0 && SIGNAL == 0)); then
    rm -fr -- "$ATTEMPTS"
  else
    printf -- '\n' >> "$ATTEMPTS"
  fi
else
  touch -- "../../data/done/$INSTANCE"
  EXIT_STATUS=125
fi

tee <<- EOF || exit "$EXIT_STATUS"
------------------------------------------------------------------
Service Stopped :: $JOB@$INSTANCE - status=$STATUS, signal=$SIGNAL
------------------------------------------------------------------
EOF

exit "$EXIT_STATUS"
