#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ROOT="${0%/*}"
TEST_DIR="$ROOT/../../var/tmp/quine-test"

rm -fr -- "$TEST_DIR"
mkdir -p -- "$TEST_DIR/"{bootstrap,snapshot-1,snapshot-2}
RECUR=bootstrap env -C "$TEST_DIR/bootstrap" -- ../../../../opt/s6/jobs/quine/run

for SNAPSHOT in snapshot-1 snapshot-2; do
  RECUR=seed env -C "$TEST_DIR/$SNAPSHOT" -- ../bootstrap/quine/instances/-/data/job quine
done

exec -- git diff --no-index --exit-code -- "$TEST_DIR/snapshot-1" "$TEST_DIR/snapshot-2"
