#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

SELF="$(realpath -- "$0")"
SCRIPT="$(realpath -- "$1")"
shift -- 1

NAME="${SCRIPT##*/}"
BUNDLE="${SCRIPT%/*}/${NAME%.*}"

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
cp -a -- "${SELF%/*}/../examples/lil/." "$BUNDLE/"
cp -p --remove-destination -- "$SCRIPT" "$BUNDLE/run.sh"
for OPTION in "$@"; do
  printf -- '%s' "${OPTION#*=}" > "$BUNDLE/env/${OPTION%%=*}"
done
