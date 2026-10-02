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
  for JOB in dog lil; do
    "$ROOT/../dl/jobs/dispatch/data/service-template.sh" "$ROOT/../dl/examples/$JOB" "$TEST_DIR/jobs/$JOB"
    [[ -L $TEST_DIR/jobs/$JOB ]]
    RECUR=seed env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh "$JOB" -
    diff --unified -- "$ROOT/../dl/examples/$JOB/run.sh" "$TEST_DIR/snapshot-1/$JOB/instances/-/data/command"
    diff --unified -- "$ROOT/../dl/jobs/dispatch/data/step.sh" "$TEST_DIR/snapshot-1/$JOB/instances/-/data/job"
    for ENV in "$ROOT/../dl/examples/$JOB/env/"*; do
      diff --unified -- "$ENV" "$TEST_DIR/snapshot-1/$JOB/instances/-/env/${ENV##*/}"
    done
  done
}

{
  cp --archive -- "$ROOT/../dl/examples" "$TEST_DIR/examples"
  S67_JOBS_DIR="$TEST_DIR/example-jobs" "$ROOT/../dl/jobs/dispatch/run.sh" "$TEST_DIR/examples"
  DEPENDENCY="$TEST_DIR/examples/lil/records"
  INBOX="$TEST_DIR/example-jobs/dog/data/inbox/lil"
  if [[ -e $TEST_DIR/example-jobs/dog/data/dependencies ]]; then
    exit 1
  fi
  if "$TEST_DIR/example-jobs/dog/data/step.sh" -; then
    exit 1
  fi
  "$TEST_DIR/example-jobs/lil/data/step.sh" -
  [[ $INBOX -ef $DEPENDENCY ]]
  [[ $(< "$INBOX/-/output/exit_status") == 0 ]]
  FIRST="$(readlink -- "$DEPENDENCY/.versions/-/latest")"
  "$TEST_DIR/example-jobs/lil/data/step.sh" -
  LATEST="$(readlink -- "$DEPENDENCY/.versions/-/latest")"
  [[ $LATEST != "$FIRST" ]]
  [[ $INBOX/- -ef $DEPENDENCY/.versions/-/$LATEST ]]
  "$TEST_DIR/example-jobs/lil/data/step.sh" other
  [[ $(< "$DEPENDENCY/other/output/exit_status") == 0 ]]
  "$TEST_DIR/example-jobs/dog/data/step.sh" -
  [[ $(< "$TEST_DIR/examples/dog/records/-/output/exit_status") == 0 ]]
  [[ $TEST_DIR/examples/dog/records/-/input/lil -ef $INBOX ]]
  [[ $(< "$TEST_DIR/examples/dog/records/-/input/lil/other/output/exit_status") == 0 ]]
}

{
  mkdir -p -- "$TEST_DIR/steps/dog/data/inbox" "$TEST_DIR/upstream/.versions/other-instance/revision/output"
  cat > "$TEST_DIR/upstream/.versions/other-instance/revision/output/exit_status" << 'EOF'
0
EOF
  cat > "$TEST_DIR/upstream/.versions/other-instance/revision/output/stdout" << 'EOF'
input from another instance
EOF
  ln -sTnf -- revision "$TEST_DIR/upstream/.versions/other-instance/latest"
  ln -sTnf -- .versions/other-instance/latest "$TEST_DIR/upstream/other-instance"
  INPUT="$(realpath -- "$TEST_DIR/upstream")"
  ln -sTnf -- "$INPUT" "$TEST_DIR/steps/dog/data/inbox/dogs"
  cat > "$TEST_DIR/steps/dog/run.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $(< input/dogs/other-instance/output/stdout) == 'input from another instance' ]]
cat << STDOUT
$1:$PAYLOAD
STDOUT

cat >&2 << STDERR
diagnostic
STDERR

exit "$RESULT"
EOF
  chmod +x -- "$TEST_DIR/steps/dog/run.sh"
  cat > "$TEST_DIR/steps/dog/dispatch.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -d records ]]
[[ -f $1/command ]]
[[ -d $1/inbox ]]
[[ -d $1/recurring ]]
[[ -d $1/oneshot ]]
[[ -z ${RECUR:-} ]]
ln -s -- /dev/null "$1/oneshot/walk"
EOF
  chmod +x -- "$TEST_DIR/steps/dog/dispatch.sh"
  S67_JOBS_DIR="$TEST_DIR/jobs" "$ROOT/../dl/jobs/dispatch/run.sh" "$TEST_DIR/steps"
  [[ -L $TEST_DIR/jobs/dog/data/oneshot/walk ]]
  cat > "$TEST_DIR/steps/dog/run.sh" << 'EOF'
exit 99
EOF

  for INSTANCE in walk feed; do
    RECUR=seed env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh dog "$INSTANCE"
    SERVICE="$TEST_DIR/snapshot-1/dog/instances/$INSTANCE"
    PAYLOAD=first RESULT=0 "$SERVICE/data/job" "$INSTANCE" 2> "$TEST_DIR/stderr"
    [[ $(< "$TEST_DIR/stderr") == diagnostic ]]
    [[ $(< "$SERVICE/data/outbox/stdout") == "$INSTANCE:first" ]]
    [[ $(< "$SERVICE/data/outbox/exit_status") == 0 ]]
    [[ -d $TEST_DIR/steps/dog/records/$INSTANCE/input ]]
  done

  SERVICE="$TEST_DIR/snapshot-1/dog/instances/walk"
  VERSIONS="$TEST_DIR/steps/dog/records/.versions/walk"
  FIRST="$(readlink -- "$VERSIONS/latest")"
  if PAYLOAD=failed RESULT=67 "$SERVICE/data/job" walk 2> "$TEST_DIR/stderr"; then
    exit 1
  else
    [[ $? == 67 ]]
  fi
  LATEST="$(readlink -- "$VERSIONS/latest")"
  [[ $LATEST == "$FIRST" ]]
  FAILED=("$VERSIONS/"*/output/exit_status)
  grep --quiet --line-regexp 67 "${FAILED[@]}"
  PAYLOAD=second RESULT=0 "$SERVICE/data/job" walk 2> "$TEST_DIR/stderr"
  LATEST="$(readlink -- "$VERSIONS/latest")"
  [[ $LATEST != "$FIRST" ]]
  [[ $(< "$VERSIONS/$FIRST/output/stdout") == walk:first ]]
  rm -fr -- "$SERVICE"
  [[ $(< "$TEST_DIR/steps/dog/records/walk/output/stdout") == walk:second ]]
  [[ $(< "$TEST_DIR/steps/dog/records/feed/output/stdout") == feed:first ]]
}
