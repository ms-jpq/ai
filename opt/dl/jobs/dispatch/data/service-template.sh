#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

SRC="$(realpath -- "$1")"
DST="${2%/}"
RUN=("$SRC"/run.*)
if ((${#RUN[@]} != 1)) || ! [[ -f ${RUN[*]} ]] || ! [[ -x ${RUN[*]} ]]; then
  set -x
  exit 2
fi

VERSIONS="${DST%/*}/.versions"
mkdir -p -- "$VERSIONS"

REVISION="$(mktemp -d -- "$VERSIONS/${DST##*/}.XXXXXX")"
LINK="${DST%/*}/.${REVISION##*/}.link"
trap 'rm -f -- "$LINK"' EXIT

rsync --archive --include='/env/***' --include='/data/***' --exclude='/*' -- "$SRC/" "$REVISION/"
mkdir -p -- "$REVISION/env" "$REVISION/data/"{inbox,recurring,oneshot} "$SRC/records"
printf -- '%s' "$SRC/records" > "$REVISION/env/S67_RECORDS_DIR"
cp --preserve=mode,timestamps -- "${RUN[*]}" "$REVISION/data/command"
cp --preserve=mode,timestamps -- "${0%/*}/step.sh" "$REVISION/data/step.sh"
ln -sTnf -- data/step.sh "$REVISION/run.sh"
ln -sTnfr -- "$REVISION" "$LINK"
mv --force --no-target-directory -- "$LINK" "$DST"
