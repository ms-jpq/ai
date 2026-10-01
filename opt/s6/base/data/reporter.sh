#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JOB_NAME="${PWD##*/}"
FAILED="$PWD/data/failed"
STATUS=0

if "$@"; then
  if ! [[ -e $FAILED ]]; then
    exit
  fi
  MESSAGE="Job $JOB_NAME recovered (exit 0)."
else
  STATUS=$?
  MESSAGE="Job $JOB_NAME failed (exit $STATUS)."
  if [[ -e $FAILED ]]; then
    printf -- '%s\n' "$MESSAGE"
    exit "$STATUS"
  fi
fi

printf -- '%s\n' "$MESSAGE"

if ((STATUS)); then
  touch -- "$FAILED"
else
  rm -- "$FAILED"
fi
exit "$STATUS"
