#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ROOT="${0%/*}"
TEST_DIR="$ROOT/../../var/tmp/quine-test"

rm -fr -- "$TEST_DIR"
mkdir -p -- "$TEST_DIR/"snapshot-{1,2,3}
cp --archive -- "$ROOT" "$TEST_DIR/s6"
ln -s -- quine "$TEST_DIR/s6/jobs/quine-2"
ln -s -- /dev/null "$TEST_DIR/s6/jobs/quine/data/null"

RECUR=bootstrap env -C "$TEST_DIR/snapshot-1" -- ../s6/jobs/quine/run.sh
RECUR=seed env -C "$TEST_DIR/snapshot-2" -- ../s6/jobs/quine-2/run.sh quine-2 -
RECUR=seed env -C "$TEST_DIR/snapshot-3" -- ../snapshot-1/quine/instances/-/data/job quine -

[[ -d $TEST_DIR/snapshot-2/quine-2/template && ! -L $TEST_DIR/snapshot-2/quine-2/template ]]
LINK="$(readlink -- "$TEST_DIR/snapshot-1/quine/template/data/null")"
[[ -L $TEST_DIR/snapshot-1/quine/template/data/null && $LINK == /dev/null ]]
git diff --no-index --exit-code -- "$TEST_DIR/snapshot-1/quine" "$TEST_DIR/snapshot-2/quine-2"
exec -- git diff --no-index --exit-code -- "$TEST_DIR/snapshot-1/quine" "$TEST_DIR/snapshot-3/quine"
