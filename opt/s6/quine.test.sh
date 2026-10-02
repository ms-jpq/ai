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
  "$ROOT/../dl/job/data/service-template.sh" "$ROOT/../dl/examples" "$TEST_DIR/jobs"
  for JOB in dog lil; do
    [[ -L $TEST_DIR/jobs/$JOB ]]
    RECUR=seed env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh "$JOB" -
    diff --unified -- "$ROOT/../dl/examples/$JOB/run.sh" "$TEST_DIR/snapshot-1/$JOB/instances/-/data/command"
    diff --unified -- "$ROOT/../dl/job/data/step.sh" "$TEST_DIR/snapshot-1/$JOB/instances/-/data/job"
    for ENV in "$ROOT/../dl/examples/$JOB/env/"*; do
      diff --unified -- "$ENV" "$TEST_DIR/snapshot-1/$JOB/instances/-/env/${ENV##*/}"
    done
  done
}

{
  mkdir -p -- "$TEST_DIR/steps/dog"
  cat > "$TEST_DIR/steps/dog/run.sh" << 'EOF'
#!/usr/bin/env bash
cat << STDOUT
$1:$PAYLOAD
STDOUT

cat >&2 << STDERR
diagnostic
STDERR

exit "$RESULT"
EOF
  chmod +x -- "$TEST_DIR/steps/dog/run.sh"
  "$ROOT/../dl/job/data/service-template.sh" "$TEST_DIR/steps" "$TEST_DIR/jobs"
  cat > "$TEST_DIR/steps/dog/run.sh" << 'EOF'
exit 99
EOF

  for INSTANCE in walk feed; do
    RECUR=seed env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh dog "$INSTANCE"
    SERVICE="$TEST_DIR/snapshot-1/dog/instances/$INSTANCE"
    PAYLOAD=first RESULT=0 "$SERVICE/data/job" "$INSTANCE" 2> "$TEST_DIR/stderr"
    [[ $(< "$TEST_DIR/stderr") == diagnostic ]]
    [[ $(< "$TEST_DIR/steps/dog/outbox/$INSTANCE/stdout") == "$INSTANCE:first" ]]
    [[ -d $SERVICE/data/versions/latest/meta ]]
  done

  SERVICE="$TEST_DIR/snapshot-1/dog/instances/walk"
  FIRST="$(readlink -- "$SERVICE/data/versions/latest")"
  if PAYLOAD=failed RESULT=7 "$SERVICE/data/job" walk 2> "$TEST_DIR/stderr"; then
    exit 1
  else
    [[ $? == 7 ]]
  fi
  LATEST="$(readlink -- "$SERVICE/data/versions/latest")"
  [[ $LATEST == "$FIRST" ]]
  PAYLOAD=second RESULT=0 "$SERVICE/data/job" walk 2> "$TEST_DIR/stderr"
  LATEST="$(readlink -- "$SERVICE/data/versions/latest")"
  [[ $LATEST != "$FIRST" ]]
  [[ $(< "$SERVICE/data/versions/$FIRST/stdout") == walk:first ]]
  rm -fr -- "$SERVICE"
  [[ $(< "$TEST_DIR/steps/dog/outbox/walk/stdout") == walk:second ]]
  [[ $(< "$TEST_DIR/steps/dog/outbox/feed/stdout") == feed:first ]]
}
