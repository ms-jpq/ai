#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

ROOT="${0%/*}"
TEST_DIR="$ROOT/../../var/tmp/quine-test"

rm -fr -- "$TEST_DIR"
mkdir -p -- "$TEST_DIR/"snapshot-{1,2}
RECUR=bootstrap env -C "$TEST_DIR/snapshot-1" -- ../../../../opt/s6/jobs/quine/run.sh

RECUR=seed env -C "$TEST_DIR/snapshot-2" -- ../snapshot-1/quine/instances/-/data/job quine

exec -- git diff --no-index --exit-code -- "$TEST_DIR/snapshot-1/quine" "$TEST_DIR/snapshot-2/quine"
