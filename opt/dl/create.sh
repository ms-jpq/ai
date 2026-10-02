#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STEP="$1"
SCRIPT="$2"
shift -- 2

if ! [[ -f $SCRIPT ]] || ! [[ -x $SCRIPT ]]; then
  set -x
  exit 2
fi
for OPTION in "$@"; do
  if [[ $OPTION != *=* ]] || [[ ${OPTION%%=*} != +([[:alnum:]_]) ]]; then
    set -x
    exit 2
  fi
done

mkdir -- "$STEP"
cp -a -- "${0%/*}/examples/lil/." "$STEP/"
cp -p --remove-destination -- "$SCRIPT" "$STEP/run.sh"

for OPTION in "$@"; do
  printf -- '%s' "${OPTION#*=}" > "$STEP/env/${OPTION%%=*}"
done
