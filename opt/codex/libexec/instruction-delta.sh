#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STATE="$1"
shift -- 1

if ! (($#)); then
  exit
fi

INITIAL=0
if ! [[ -d $STATE ]]; then
  INITIAL=1
fi
mkdir -p -- "$STATE"

DELTA="$(rsync --recursive --copy-links --relative --checksum --delete --out-format='%n' -- "$@" "$STATE/")"

if ((INITIAL)) || [[ -z $DELTA ]]; then
  exit
fi

tee << EOF
<system-reminder>
Instruction files changed.

$DELTA
</system-reminder>
EOF
