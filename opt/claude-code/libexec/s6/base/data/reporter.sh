#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

: "${S67_WORKSPACE?}"

JOB_NAME="${PWD##*/}"
FAILED="$PWD/data/failed"
EVENTS="$S67_WORKSPACE/.notes/events"
STATUS=0

if "$@"; then
  if ! [[ -e $FAILED ]]; then
    exit
  fi
  MESSAGE="Job $JOB_NAME recovered (exit 0)."
else
  STATUS=$?
  MESSAGE="Job $JOB_NAME failed (exit $STATUS)."
  printf -- '%s\n' "$MESSAGE"
  if [[ -e $FAILED ]]; then
    exit "$STATUS"
  fi
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p -- "$EVENTS"
NOTICE="$(mktemp "$EVENTS/../.s6-event.XXXXXX")"
tee -- "$NOTICE" <<- EOF
$TIMESTAMP
$MESSAGE
Log: $PWD/../../log/job-$JOB_NAME.log/current
EOF
mv -- "$NOTICE" "$EVENTS/${NOTICE##*/}"
touch -- "$S67_WORKSPACE/.events-ready"

if ((STATUS)); then
  touch -- "$FAILED"
else
  rm -- "$FAILED"
fi
exit "$STATUS"
