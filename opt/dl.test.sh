#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if (($# == 0)); then
  printf '%s\n' create invalid | shuf | xargs --max-procs=0 --max-args=1 -- "$0"
  exit
fi
trap 'printf "%s [%s]:%s: %s\n" "$0" "$1" "$LINENO" "$BASH_COMMAND" >&2' ERR

ROOT="${0%.test.sh}"
mkdir -p -- "$ROOT/../../var/tmp"
TEST_DIR="$(mktemp -d -- "$ROOT/../../var/tmp/dl-test.XXXXXX")"
TEST_DIR="$(realpath -- "$TEST_DIR")"
trap 'rm -fr -- "$TEST_DIR"' EXIT
STEP="$TEST_DIR/dog house"
SCRIPT="$TEST_DIR/run.sh"
cat > "$SCRIPT" << 'BASH'
#!/usr/bin/env bash
printf '%s\n' "$1"
BASH
chmod +x -- "$SCRIPT"

case "$1" in
create)
  "$ROOT/create.sh" "$STEP" "$SCRIPT" 'PAYLOAD=two dogs=good' 'EMPTY=' S9_ON_UNIT_INACTIVE_SEC=67
  for DIR in env wants outbox; do
    [[ -d $STEP/$DIR ]]
  done
  [[ -x $STEP/run.sh ]]
  if [[ -L $STEP/run.sh ]]; then exit 1; fi
  diff --unified -- "$SCRIPT" "$STEP/run.sh"
  [[ $(< "$STEP/env/PAYLOAD") == 'two dogs=good' ]]
  [[ -f $STEP/env/EMPTY ]]
  if [[ -s $STEP/env/EMPTY ]]; then exit 1; fi
  [[ $(< "$STEP/env/S9_ON_UNIT_INACTIVE_SEC") == 67 ]]
  ACTUAL="$("$STEP/run.sh" walk)"
  [[ $ACTUAL == walk ]]
  printf '%s\n' 'exit 67' > "$SCRIPT"
  if "$ROOT/create.sh" "$STEP" "$SCRIPT" PAYLOAD=changed 2> "$TEST_DIR/error"; then exit 1; fi
  [[ $(< "$STEP/env/PAYLOAD") == 'two dogs=good' ]]
  ACTUAL="$("$STEP/run.sh" walk)"
  [[ $ACTUAL == walk ]]
  ;;
invalid)
  for OPTION in missing-equals '=empty-name' '../escape=value' 'bad-name=value'; do
    if "$ROOT/create.sh" "$STEP" "$SCRIPT" "$OPTION" 2> "$TEST_DIR/error"; then exit 1; else [[ $? == 2 ]]; fi
    if [[ -e $STEP ]]; then exit 1; fi
  done
  chmod -x -- "$SCRIPT"
  for SCRIPT in "$SCRIPT" "$TEST_DIR/missing"; do
    if "$ROOT/create.sh" "$STEP" "$SCRIPT" 2> "$TEST_DIR/error"; then exit 1; else [[ $? == 2 ]]; fi
    if [[ -e $STEP ]]; then exit 1; fi
  done
  ;;
*)
  set -x
  exit 2
  ;;
esac
