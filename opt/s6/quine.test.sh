#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ROOT="${0%/*}"
TEST_DIR="$ROOT/../../var/tmp/quine-test"

{
  rm -fr -- "$TEST_DIR"
  mkdir -p -- "$TEST_DIR/"snapshot-{1,2,3}
  cp --archive -- "$ROOT/." "$TEST_DIR/"
  ln -sTnfr -- "$TEST_DIR/jobs/quine" "$TEST_DIR/jobs/quine-2"
  ln -sTnf -- /dev/null "$TEST_DIR/jobs/quine/data/null"

  RECUR=bootstrap env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh
  RECUR=seed env -C "$TEST_DIR/snapshot-2" -- ../jobs/quine-2/run.sh quine-2 -
  RECUR=seed env -C "$TEST_DIR/snapshot-3" -- ../snapshot-1/quine/instances/-/data/job quine -

  [[ -d $TEST_DIR/snapshot-2/quine-2/template ]]
  if [[ -L $TEST_DIR/snapshot-2/quine-2/template ]]; then
    exit 1
  fi
  LINK="$(readlink -- "$TEST_DIR/snapshot-1/quine/template/data/null")"
  [[ -L $TEST_DIR/snapshot-1/quine/template/data/null ]]
  [[ $LINK == /dev/null ]]

  diff --recursive --no-dereference --unified --from-file="$TEST_DIR/snapshot-1/quine" -- "$TEST_DIR/snapshot-2/quine-2" "$TEST_DIR/snapshot-3/quine"
}

{
  "$ROOT/../dl/job/data/s6-template.sh" "$ROOT/../dl/examples" "$TEST_DIR/jobs"
  for JOB in dog lil; do
    [[ -L $TEST_DIR/jobs/$JOB ]]
    RECUR=seed env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh "$JOB" -
    diff --unified -- "$ROOT/../dl/examples/$JOB/run.sh" "$TEST_DIR/snapshot-1/$JOB/instances/-/data/job"
    for ENV in "$ROOT/../dl/examples/$JOB/env/"*; do
      diff --unified -- "$ENV" "$TEST_DIR/snapshot-1/$JOB/instances/-/env/${ENV##*/}"
    done
  done
}
