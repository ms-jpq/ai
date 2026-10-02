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
    EXPECTED_RECORDS="$(realpath -- "$ROOT/../dl/examples/$JOB/records")"
    [[ $(< "$TEST_DIR/snapshot-1/$JOB/instances/-/env/S67_RECORDS_DIR") == "$EXPECTED_RECORDS" ]]
    if [[ -e $TEST_DIR/jobs/$JOB/data/records ]] || [[ -L $TEST_DIR/jobs/$JOB/data/records ]]; then
      exit 1
    fi
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
  if s6-envdir -- "$TEST_DIR/example-jobs/dog/env" "$TEST_DIR/example-jobs/dog/data/step.sh" -; then
    exit 1
  fi
  s6-envdir -- "$TEST_DIR/example-jobs/lil/env" "$TEST_DIR/example-jobs/lil/data/step.sh" -
  [[ $INBOX -ef $DEPENDENCY ]]
  [[ $(< "$INBOX/-/latest/output/exit_status") == 0 ]]
  FIRST="$(readlink -- "$DEPENDENCY/-/latest")"
  s6-envdir -- "$TEST_DIR/example-jobs/lil/env" "$TEST_DIR/example-jobs/lil/data/step.sh" -
  LATEST="$(readlink -- "$DEPENDENCY/-/latest")"
  [[ $LATEST != "$FIRST" ]]
  [[ $INBOX/-/latest -ef $DEPENDENCY/-/$LATEST ]]
  s6-envdir -- "$TEST_DIR/example-jobs/lil/env" "$TEST_DIR/example-jobs/lil/data/step.sh" other
  [[ $(< "$DEPENDENCY/other/latest/output/exit_status") == 0 ]]
  s6-envdir -- "$TEST_DIR/example-jobs/dog/env" "$TEST_DIR/example-jobs/dog/data/step.sh" -
  [[ $(< "$TEST_DIR/examples/dog/records/-/latest/output/exit_status") == 0 ]]
  [[ $TEST_DIR/examples/dog/records/-/latest/input/lil -ef $INBOX ]]
  [[ $(< "$TEST_DIR/examples/dog/records/-/latest/input/lil/other/latest/output/exit_status") == 0 ]]
}

{
  mkdir -p -- "$TEST_DIR/steps/dog/data/inbox" "$TEST_DIR/upstream/other-instance/revision/output"
  cat > "$TEST_DIR/upstream/other-instance/revision/output/exit_status" << 'EOF'
0
EOF
  cat > "$TEST_DIR/upstream/other-instance/revision/output/stdout" << 'EOF'
input from another instance
EOF
  ln -sTnf -- revision "$TEST_DIR/upstream/other-instance/latest"
  INPUT="$(realpath -- "$TEST_DIR/upstream")"
  ln -sTnf -- "$INPUT" "$TEST_DIR/steps/dog/data/inbox/dogs"
  cat > "$TEST_DIR/steps/dog/run.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $(< input/dogs/other-instance/latest/output/stdout) == 'input from another instance' ]]
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
    PAYLOAD=first RESULT=0 s6-envdir -- "$SERVICE/env" "$SERVICE/data/job" "$INSTANCE" 2> "$TEST_DIR/stderr"
    [[ $(< "$TEST_DIR/stderr") == diagnostic ]]
    [[ $(< "$SERVICE/data/outbox/stdout") == "$INSTANCE:first" ]]
    [[ $(< "$SERVICE/data/outbox/exit_status") == 0 ]]
    [[ -d $TEST_DIR/steps/dog/records/$INSTANCE/latest/input ]]
  done

  SERVICE="$TEST_DIR/snapshot-1/dog/instances/walk"
  VERSIONS="$TEST_DIR/steps/dog/records/walk"
  FIRST="$(readlink -- "$VERSIONS/latest")"
  if PAYLOAD=failed RESULT=67 s6-envdir -- "$SERVICE/env" "$SERVICE/data/job" walk 2> "$TEST_DIR/stderr"; then
    exit 1
  else
    [[ $? == 67 ]]
  fi
  LATEST="$(readlink -- "$VERSIONS/latest")"
  [[ $LATEST == "$FIRST" ]]
  [[ $(< "$SERVICE/data/outbox/stdout") == walk:failed ]]
  [[ $(< "$SERVICE/data/outbox/exit_status") == 67 ]]
  if [[ $SERVICE/data/outbox -ef $VERSIONS/latest/output ]]; then
    exit 1
  fi
  FAILED=("$VERSIONS/"*/output/exit_status)
  grep --quiet --line-regexp 67 "${FAILED[@]}"
  PAYLOAD=second RESULT=0 s6-envdir -- "$SERVICE/env" "$SERVICE/data/job" walk 2> "$TEST_DIR/stderr"
  LATEST="$(readlink -- "$VERSIONS/latest")"
  [[ $LATEST != "$FIRST" ]]
  [[ $(< "$VERSIONS/$FIRST/output/stdout") == walk:first ]]
  [[ $SERVICE/data/outbox -ef $VERSIONS/latest/output ]]
  rm -fr -- "$SERVICE"
  [[ $(< "$TEST_DIR/steps/dog/records/walk/latest/output/stdout") == walk:second ]]
  [[ $(< "$TEST_DIR/steps/dog/records/feed/latest/output/stdout") == feed:first ]]
}

{
  mkdir -p -- "$TEST_DIR/queue-step" "$TEST_DIR/bin"
  cp --preserve=mode -- "$ROOT/../dl/examples/dog/run.sh" "$TEST_DIR/queue-step/run.sh"
  cat > "$TEST_DIR/bin/s6-instance-create" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
MANAGER="${@: -2:1}"
INSTANCE="${@: -1}"
if [[ $INSTANCE == rejected ]]; then
  exit 67
fi
mkdir -p -- "$MANAGER/instances/$INSTANCE"
cp --archive -- "$MANAGER/template/." "$MANAGER/instances/$INSTANCE/"
EOF
  cat > "$TEST_DIR/bin/noop" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x -- "$TEST_DIR/bin/"{s6-instance-create,noop}
  for COMMAND in s6-svok s6-svwait s6-svc s6-instance-control; do
    ln -s -- noop "$TEST_DIR/bin/$COMMAND"
  done
  TEST_BIN="$(realpath -- "$TEST_DIR/bin")"
  for PASS in 1 2; do
    "$ROOT/../dl/jobs/dispatch/data/service-template.sh" "$TEST_DIR/queue-step" "$TEST_DIR/jobs/queue-dog"
    printf -- 'Prepared queue snapshot %s\n' "$PASS"
  done
  ln -s -- /dev/null "$TEST_DIR/jobs/queue-dog/data/recurring/keep"
  ln -s -- /missing/inbox "$TEST_DIR/jobs/queue-dog/data/oneshot/run"
  ln -s -- /dev/null "$TEST_DIR/jobs/queue-dog/data/oneshot/.pending"
  PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh queue-dog
  [[ -d $TEST_DIR/snapshot-1/queue-dog/instances/keep ]]
  [[ -d $TEST_DIR/snapshot-1/queue-dog/instances/run ]]
  [[ -L $TEST_DIR/jobs/queue-dog/data/recurring/keep ]]
  if [[ -L $TEST_DIR/jobs/queue-dog/data/oneshot/run ]] || [[ -d $TEST_DIR/snapshot-1/queue-dog/instances/.pending ]]; then
    exit 1
  fi
  [[ -L $TEST_DIR/jobs/queue-dog/data/oneshot/.pending ]]

  ln -s -- /dev/null "$TEST_DIR/jobs/queue-dog/data/oneshot/rejected"
  if PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh queue-dog; then
    exit 1
  fi
  [[ -L $TEST_DIR/jobs/queue-dog/data/oneshot/rejected ]]
  "$ROOT/../dl/jobs/dispatch/data/service-template.sh" "$TEST_DIR/queue-step" "$TEST_DIR/jobs/queue-dog"
  [[ -L $TEST_DIR/jobs/queue-dog/data/oneshot/rejected ]]
  if [[ -L $TEST_DIR/jobs/queue-dog/data/oneshot/run ]]; then
    exit 1
  fi
}
