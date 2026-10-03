#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if (($# == 0)); then
  printf '%s\n' templates graph | shuf | xargs --max-procs=0 --max-args=1 -- "$0"
  exit
fi
trap 'printf "%s [%s]:%s: %s\n" "$0" "$1" "$LINENO" "$BASH_COMMAND" >&2' ERR

ROOT="${0%.test.sh}"
TEMPLATE="$ROOT/jobs/dispatch/data/service-template.sh"
mkdir -p -- "$ROOT/../../var/tmp"
TEST_DIR="$(mktemp -d -- "$ROOT/../../var/tmp/dl-test.XXXXXX")"
TEST_DIR="$(realpath -- "$TEST_DIR")"
trap 'rm -fr -- "$TEST_DIR"' EXIT
JOBS="$TEST_DIR/jobs"

case "$1" in
graph)
  cp --archive -- "$ROOT/examples" "$TEST_DIR/examples"
  S9_JOBS_DIR="$JOBS" "$ROOT/jobs/dispatch/run.sh" "$TEST_DIR/examples"
  DOG=(s6-envdir -- "$JOBS/dog/env" "$JOBS/dog/data/step.sh")
  LIL=(s6-envdir -- "$JOBS/lil/env" "$JOBS/lil/data/step.sh")
  DEPENDENCY="$TEST_DIR/examples/lil/records"
  RECORD="$TEST_DIR/examples/dog/records/-/latest"
  INBOX="$JOBS/dog/data/inbox/lil"
  if [[ -e $JOBS/dog/data/dependencies ]]; then
    exit 1
  fi
  if "${DOG[@]}" -; then
    exit 1
  fi
  "${LIL[@]}" -
  [[ $INBOX -ef $DEPENDENCY ]]
  [[ $(< "$INBOX/-/latest/output/exit_status") == 0 ]]
  FIRST="$(readlink -- "$DEPENDENCY/-/latest")"
  "${LIL[@]}" -
  LATEST="$(readlink -- "$DEPENDENCY/-/latest")"
  [[ $LATEST != "$FIRST" ]]
  [[ $INBOX/-/latest -ef $DEPENDENCY/-/$LATEST ]]
  "${LIL[@]}" other
  [[ $(< "$DEPENDENCY/other/latest/output/exit_status") == 0 ]]
  "${DOG[@]}" -
  [[ $(< "$RECORD/output/exit_status") == 0 ]]
  [[ $RECORD/input/lil -ef $INBOX ]]
  [[ $(< "$RECORD/input/lil/other/latest/output/exit_status") == 0 ]]
  ;;
templates)
  SRC="$TEST_DIR/steps/dog house"
  DST="$JOBS/dog house"
  LAUNCH="$DST/data/launch"
  SOURCE_LAUNCH="$SRC/launch"
  DEPENDENCY="$TEST_DIR/steps/lil"
  mkdir -p -- "$SOURCE_LAUNCH" "$SRC/data/inbox" "$SRC/wants" "$DEPENDENCY"
  ln -s -- ../../lil "$SRC/wants/lil"
  ln -s -- /missing/old-records "$SRC/data/inbox/lil"
  cat > "$SRC/run.sh" << 'BASH'
#!/usr/bin/env bash
exit 0
BASH
  chmod +x -- "$SRC/run.sh"
  ln -s -- ../data/inbox "$SOURCE_LAUNCH/initial"

  "$TEMPLATE" "$SRC" "$DST"
  FIRST="$(realpath -- "$DST")"
  INBOX="$(readlink -- "$DST/data/inbox/lil")"
  DEPENDENCY="$(realpath -- "$DEPENDENCY")"
  [[ $INBOX == "$DEPENDENCY/records" ]]
  mkdir -p -- "$DEPENDENCY/records/walk/revision/output"
  ln -s -- revision "$DEPENDENCY/records/walk/latest"
  [[ $DST/data/inbox/lil/walk/latest/output -ef $DEPENDENCY/records/walk/revision/output ]]
  [[ -L $LAUNCH ]]
  [[ $LAUNCH -ef $SOURCE_LAUNCH ]]
  ln -s -- ../data/inbox "$LAUNCH/queued request"
  ln -s -- /missing/inbox "$LAUNCH/.pending"
  rm -- "$LAUNCH/initial"
  if [[ -L $SOURCE_LAUNCH/initial ]]; then
    exit 1
  fi

  cat > "$SRC/run.sh" << 'BASH'
#!/usr/bin/env bash
exit 67
BASH
  "$TEMPLATE" "$SRC" "$DST"
  CURRENT="$(realpath -- "$DST")"
  [[ $CURRENT != "$FIRST" ]]
  diff --unified -- "$SRC/run.sh" "$DST/data/command"
  [[ -L $LAUNCH ]]
  [[ $LAUNCH -ef $FIRST/data/launch ]]
  [[ -L $LAUNCH/queued\ request ]]
  [[ $LAUNCH/queued\ request -ef $SRC/data/inbox ]]
  [[ -L $LAUNCH/.pending ]]
  if [[ -L $LAUNCH/initial ]]; then
    exit 1
  fi
  "$FIRST/data/command"

  ln -s -- /dev/null "$FIRST/data/launch/late"
  [[ -L $LAUNCH/late ]]
  rm -- "$LAUNCH/queued request"
  "$TEMPLATE" "$SRC" "$DST"
  if [[ -L $LAUNCH/queued\ request ]]; then
    exit 1
  fi
  [[ -L $LAUNCH/late ]]

  BEFORE="$(readlink -- "$DST")"
  chmod -x -- "$SRC/run.sh"
  if "$TEMPLATE" "$SRC" "$DST" 2> "$TEST_DIR/error"; then
    exit 1
  else
    [[ $? == 2 ]]
  fi
  AFTER="$(readlink -- "$DST")"
  [[ $BEFORE == "$AFTER" ]]
  [[ -L $LAUNCH/late ]]

  chmod +x -- "$SRC/run.sh"
  ln -s -- /missing/dependency "$SRC/wants/missing"
  if "$TEMPLATE" "$SRC" "$DST" 2> "$TEST_DIR/error"; then
    exit 1
  fi
  AFTER="$(readlink -- "$DST")"
  [[ $AFTER == "$BEFORE" ]]
  ;;
*)
  set -x
  exit 2
  ;;
esac
