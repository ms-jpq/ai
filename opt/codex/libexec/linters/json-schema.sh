#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

FILE_PATH="$1"
BASE="${0%/*}"
FILE_DIR="${FILE_PATH%/*}"

AJV="$BASE/../../../../node_modules/.bin/ajv"
if [[ ! -x $AJV ]]; then
  AJV="$(command -v -- ajv)"
fi

SCHEMA=""
case "$FILE_PATH" in
*.json)
  ;;
*.yml | *.yaml)
  # shellcheck disable=SC2016
  SCHEMA="$(sed -E -n -e '1{s@^[[:space:]]*#[[:space:]]*(yaml-language-server:[[:space:]]*)?\$schema[[:space:]]*[:=][[:space:]]*([^[:space:]]+)[[:space:]]*$@\2@p;}' -- "$FILE_PATH")"
  ;;
*.toml)
  SCHEMA="$(sed -E -n -e '1{s@^[[:space:]]*#:[[:space:]]*schema[[:space:]]+([^[:space:]]+)[[:space:]]*$@\1@p;}' -- "$FILE_PATH")"
  ;;
*)
  set -x
  exit 2
  ;;

esac

if [[ -z $SCHEMA ]]; then
  # shellcheck disable=SC2016
  SCHEMA="$(yq --no-colors --unwrapScalar '."$schema" // ""' -- "$FILE_PATH")"
fi

if [[ -z $SCHEMA || $SCHEMA == none ]]; then
  exit
fi

TMPDIR="${TMPDIR:-/tmp}/json-schema"
mkdir -p -- "$TMPDIR"

HASH="$(b3sum <<< "$SCHEMA")"
HASH="${HASH%% *}"
SCHEMA_CACHE="$TMPDIR/$HASH.json"

TMP="$(mktemp -d "$TMPDIR/data.XXXXXX")"
trap 'rm -fr -- "$TMP"' EXIT

case "$SCHEMA" in
file://*)
  SCHEMA_PATH="${SCHEMA#file://}"
  ;;
http://* | https://*)
  if [[ ! -f $SCHEMA_CACHE ]]; then
    curl --fail --location --output "$TMP/schema.json" -- "$SCHEMA"
    mv -n -- "$TMP/schema.json" "$SCHEMA_CACHE"
  fi
  SCHEMA_PATH="$SCHEMA_CACHE"
  ;;
/*)
  SCHEMA_PATH="$(realpath -- "$SCHEMA")"
  ;;
*)
  SCHEMA_PATH="$(realpath -- "$FILE_DIR/$SCHEMA")"
  ;;
esac

JSON="$TMP/data.json"
yq --output-format=json --unwrapScalar=false '.' -- "$FILE_PATH" > "$JSON"

STATUS=0
if OUTPUT="$("$AJV" validate --spec=draft2020 --errors=text --all-errors -s "$SCHEMA_PATH" -d "$JSON" 2>&1)"; then
  :
else
  STATUS=$?
fi

printf -- '%s' "${OUTPUT//$JSON/$FILE_PATH}"
exit "$STATUS"
