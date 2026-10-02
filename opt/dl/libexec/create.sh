#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SCRIPT="$1"
shift -- 1

NAME="${SCRIPT##*/}"
BUNDLE="${SCRIPT%"$NAME"}${NAME%.*}"

if ! [[ -f $SCRIPT && -x $SCRIPT ]]; then
  set -x
  exit 2
fi
for OPTION in "$@"; do
  if [[ $OPTION != *=* || ${OPTION%%=*} != +([[:alnum:]_]) ]]; then
    set -x
    exit 2
  fi
done

mkdir -- "$BUNDLE"
cp -a -- "${0%/*}/../examples/lil/." "$BUNDLE/"
cp -p --remove-destination -- "$SCRIPT" "$BUNDLE/run.sh"

for OPTION in "$@"; do
  printf -- '%s' "${OPTION#*=}" > "$BUNDLE/env/${OPTION%%=*}"
done
