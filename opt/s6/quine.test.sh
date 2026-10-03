#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if (($# == 0)); then
  printf '%s\n' snapshots templates graph execution queues policy lifecycle | shuf | xargs --max-procs=0 --max-args=1 -- "$0"
  exit
fi
trap 'printf "%s [%s]:%s: %s\n" "$0" "$1" "$LINENO" "$BASH_COMMAND" >&2' ERR

ROOT="${0%/*}"
DL="$ROOT/../dl"
TEMPLATE="$DL/jobs/dispatch/data/service-template.sh"
mkdir -p -- "$ROOT/../../var/tmp"
TEST_DIR="$(mktemp -d -- "$ROOT/../../var/tmp/quine-test.XXXXXX")"
trap 'rm -fr -- "$TEST_DIR"' EXIT
mkdir -- "$TEST_DIR/snapshot-1"
cp --archive -- "$ROOT/." "$TEST_DIR/"

case "$1" in
lifecycle)
  TEST_DIR="$(realpath -- "$TEST_DIR")"
  STATE="$TEST_DIR/snapshot-1"
  STEP="$TEST_DIR/steps/dog"
  JOB="$TEST_DIR/jobs/dog"
  SERVICE="$STATE/dog/instances/walk"
  QUINE="$TEST_DIR/jobs/quine/run.sh"
  WAIT=(timeout --foreground 15s bash -c 'until test "$@"; do sleep 0.05; done' --)
  export S67_WORKING_DIRECTORY="$TEST_DIR"
  mkdir -p -- "$STEP/env" "$STEP/data" "$TEST_DIR/jobs/keeper/env"
  printf '%s' 10 > "$TEST_DIR/base/env/S67_RUNTIME_MAX_SEC"
  cat > "$STEP/run.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
CODE=old
printf '%s:%s:%s\n' "$CODE" "$PAYLOAD" "$(< "${0%/*}/value")" > "$S67_WORKING_DIRECTORY/started-$PAYLOAD"
while ! [[ -f $S67_WORKING_DIRECTORY/release-$PAYLOAD ]]; do sleep 0.05; done
printf '%s\n' "$CODE" > "$S67_WORKING_DIRECTORY/finished-$PAYLOAD"
EOF
  chmod +x -- "$STEP/run.sh"
  touch -- "$STEP/env/S67_DAEMON" "$TEST_DIR/jobs/keeper/env/S67_DAEMON"
  printf '%s' one > "$STEP/env/PAYLOAD"
  printf '%s' old-data > "$STEP/data/value"
  "$TEMPLATE" "$STEP" "$JOB"
  ln -s -- /dev/null "$STEP/launch/walk"
  RECUR=bootstrap env -C "$STATE" -- "$QUINE" quine
  cat > "$TEST_DIR/jobs/keeper/run.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x -- "$TEST_DIR/jobs/keeper/run.sh"
  RECUR=seed env -C "$STATE" -- "$QUINE" keeper parent
  mkdir -p -- "$STATE/keeper/data/launch"
  ln -s -- /dev/null "$STATE/keeper/data/launch/parent"

  s6-svscan -- "$STATE" > "$TEST_DIR/scan.log" 2>&1 &
  SCAN_PID=$!
  RESULT=0
  trap '
    RESULT=$?
    if ! s6-svscanctl -t -- "$STATE"; then
      RESULT=1
      find "$STATE" -type d -name supervise -exec s6-svc -dx -- "{}/.." \;
    fi
    if ! wait "$SCAN_PID"; then RESULT=1; fi
    if ((RESULT)); then
      cat -- "$TEST_DIR/scan.log" >&2
      find "$TEST_DIR/log" -type f -name "*.log" -exec cat -- {} + >&2
    fi
    rm -fr -- "$TEST_DIR"
    exit "$RESULT"
  ' EXIT

  "${WAIT[@]}" -s "$TEST_DIR/started-one"
  [[ $(< "$TEST_DIR/started-one") == old:one:old-data ]]
  PID="$(s6-svstat -o pid -- "$SERVICE")"
  "$TEMPLATE" "$STEP" "$JOB"
  RECUR=job env -C "$STATE" -- s6-setlock -- "$STATE/.reconcile.lock" "$QUINE" dog
  if [[ -f $SERVICE/down ]]; then exit 1; fi
  CURRENT_PID="$(s6-svstat -o pid -- "$SERVICE")"
  [[ $CURRENT_PID == "$PID" ]]

  sed -i -e 's/CODE=old/CODE=new/' -- "$STEP/run.sh"
  printf '%s' two > "$STEP/env/PAYLOAD"
  printf '%s' new-data > "$STEP/data/value"
  "$TEMPLATE" "$STEP" "$JOB"
  "${WAIT[@]}" -f "$SERVICE/down"
  CURRENT_PID="$(s6-svstat -o pid -- "$SERVICE")"
  [[ $CURRENT_PID == "$PID" ]]
  if [[ -f $TEST_DIR/finished-one ]]; then exit 1; fi
  touch -- "$TEST_DIR/release-one"
  "${WAIT[@]}" -s "$TEST_DIR/started-two"
  [[ $(< "$TEST_DIR/finished-one") == old ]]
  [[ $(< "$TEST_DIR/started-two") == new:two:new-data ]]

  for ATTEMPT in two three four; do
    case "$ATTEMPT" in
    two) rm -- "$STEP/launch/walk" ;;
    three) mv -- "$STEP" "$TEST_DIR/removed-step" ;;
    four) rm -- "$JOB" ;;
    *)
      set -x
      exit 2
      ;;
    esac
    "${WAIT[@]}" -f "$SERVICE/down"
    if [[ -f $TEST_DIR/finished-$ATTEMPT ]]; then exit 1; fi
    touch -- "$TEST_DIR/release-$ATTEMPT"
    "${WAIT[@]}" ! -d "$SERVICE"
    [[ $(< "$TEST_DIR/finished-$ATTEMPT") == new ]]
    case "$ATTEMPT" in
    two)
      printf '%s' three > "$STEP/env/PAYLOAD"
      "$TEMPLATE" "$STEP" "$JOB"
      ln -s -- /dev/null "$STEP/launch/walk"
      "${WAIT[@]}" -s "$TEST_DIR/started-three"
      ;;
    three)
      STEP="$TEST_DIR/removed-step"
      printf '%s' four > "$STEP/env/PAYLOAD"
      "$TEMPLATE" "$STEP" "$JOB"
      "${WAIT[@]}" -s "$TEST_DIR/started-four"
      ;;
    four) ;;
    *)
      set -x
      exit 2
      ;;
    esac
  done
  [[ -d $STATE/keeper/instances/parent ]]
  if [[ -f $STATE/keeper/instances/parent/down ]]; then exit 1; fi
  STATUS="$(s6-svstat -o wantedup -- "$STATE/quine/instances/-")"
  [[ $STATUS == true ]]
  ;;
snapshots)
  mkdir -- "$TEST_DIR/"snapshot-{2,3}
  ln -sTnfr -- "$TEST_DIR/jobs/quine" "$TEST_DIR/jobs/quine-2"
  ln -sTnf -- /dev/null "$TEST_DIR/jobs/quine/data/null"

  RECUR=bootstrap env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh quine
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
  ;;

templates)
  cp --archive -- "$DL/examples" "$TEST_DIR/examples"
  for JOB in dog lil; do
    SERVICE="$TEST_DIR/snapshot-1/$JOB/instances/-"
    "$TEMPLATE" "$TEST_DIR/examples/$JOB" "$TEST_DIR/jobs/$JOB"
    [[ -L $TEST_DIR/jobs/$JOB ]]
    RECUR=seed env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh "$JOB" -
    diff --unified -- "$DL/examples/$JOB/run.sh" "$SERVICE/data/command"
    diff --unified -- "$DL/jobs/dispatch/data/step.sh" "$SERVICE/data/job"
    EXPECTED_RECORDS="$(realpath -- "$TEST_DIR/examples/$JOB/records")"
    [[ $(< "$SERVICE/env/S67_RECORDS_DIR") == "$EXPECTED_RECORDS" ]]
    if [[ -e $TEST_DIR/jobs/$JOB/data/records ]] || [[ -L $TEST_DIR/jobs/$JOB/data/records ]]; then
      exit 1
    fi
    for ENV in "$DL/examples/$JOB/env/"*; do
      diff --unified -- "$ENV" "$SERVICE/env/${ENV##*/}"
    done
  done
  ;;

graph)
  cp --archive -- "$DL/examples" "$TEST_DIR/examples"
  S67_JOBS_DIR="$TEST_DIR/example-jobs" "$DL/jobs/dispatch/run.sh" "$TEST_DIR/examples"
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
  ;;

execution)
  mkdir -p -- "$TEST_DIR/steps/dog/data/inbox"
  for DEPENDENCY in dogs rules; do
    for INSTANCE in other-instance second-instance; do
      OUTPUT="$TEST_DIR/upstream/$DEPENDENCY/$INSTANCE/revision/output"
      mkdir -p -- "$OUTPUT"
      cat > "$OUTPUT/exit_status" << 'EOF'
0
EOF
      cat > "$OUTPUT/stdout" << EOF
$DEPENDENCY:$INSTANCE
EOF
      ln -sTnf -- revision "$TEST_DIR/upstream/$DEPENDENCY/$INSTANCE/latest"
    done
    INPUT="$(realpath -- "$TEST_DIR/upstream/$DEPENDENCY")"
    ln -sTnf -- "$INPUT" "$TEST_DIR/steps/dog/data/inbox/$DEPENDENCY"
  done
  cat > "$TEST_DIR/steps/dog/run.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
for DEPENDENCY in dogs rules; do
  for INSTANCE in other-instance second-instance; do
    [[ $(< "input/$DEPENDENCY/$INSTANCE/latest/output/stdout") == "$DEPENDENCY:$INSTANCE" ]]
  done
done
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
[[ -d $1/launch ]]
[[ -z ${RECUR:-} ]]
ln -s -- /dev/null "$1/launch/walk"
EOF
  chmod +x -- "$TEST_DIR/steps/dog/dispatch.sh"
  S67_JOBS_DIR="$TEST_DIR/jobs" "$DL/jobs/dispatch/run.sh" "$TEST_DIR/steps"
  [[ -L $TEST_DIR/jobs/dog/data/launch/walk ]]
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
  ;;

queues)
  JOB="$TEST_DIR/jobs/queue-dog"
  LAUNCH="$JOB/data/launch"
  MANAGER="$TEST_DIR/snapshot-1/queue-dog"
  mkdir -p -- "$TEST_DIR/queue-step" "$TEST_DIR/bin"
  cp --preserve=mode -- "$DL/examples/dog/run.sh" "$TEST_DIR/queue-step/run.sh"
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
  cat > "$TEST_DIR/bin/s6-svstat" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "${TEST_STATUS:-true}"
EOF
  cat > "$TEST_DIR/bin/s6-instance-delete" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
rm -fr -- "${@: -2:1}/instances/${@: -1}"
EOF
  chmod +x -- "$TEST_DIR/bin/"{s6-instance-create,s6-instance-delete,s6-svstat,noop}
  for COMMAND in s6-svok s6-svwait s6-svc s6-instance-control; do
    ln -s -- noop "$TEST_DIR/bin/$COMMAND"
  done
  TEST_BIN="$(realpath -- "$TEST_DIR/bin")"
  for _ in 1 2; do
    "$TEMPLATE" "$TEST_DIR/queue-step" "$JOB"
  done
  ln -s -- /missing/inbox "$LAUNCH/run"
  ln -s -- /dev/null "$LAUNCH/.pending"
  PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh queue-dog
  [[ -d $MANAGER/instances/run ]]
  [[ -L $MANAGER/instances/run/data/launch ]]
  if [[ -L $LAUNCH/run ]] || [[ -d $MANAGER/instances/.pending ]]; then
    exit 1
  fi
  [[ -L $LAUNCH/.pending ]]

  ln -s -- /dev/null "$LAUNCH/rejected"
  if PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh queue-dog; then
    exit 1
  fi
  [[ -L $LAUNCH/rejected ]]
  "$TEMPLATE" "$TEST_DIR/queue-step" "$JOB"
  [[ -L $LAUNCH/rejected ]]
  if [[ -L $LAUNCH/run ]]; then
    exit 1
  fi

  ln -s -- /dev/null "$LAUNCH/run"
  if env -C "$MANAGER/instances/run" -- ./finish 0 0 run > "$TEST_DIR/finish.log"; then
    exit 1
  else
    [[ $? == 125 ]]
  fi
  [[ -L $LAUNCH/run ]]
  [[ -f $MANAGER/data/done/run ]]
  if [[ -L $MANAGER/instances/run/data/launch ]]; then
    exit 1
  fi

  mkdir -- "$TEST_DIR/queue-step/env"
  touch -- "$TEST_DIR/queue-step/env/S67_DAEMON"
  rm -- "$LAUNCH/rejected"
  "$TEMPLATE" "$TEST_DIR/queue-step" "$TEST_DIR/jobs/daemon-dog"
  PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh daemon-dog
  [[ -f $TEST_DIR/snapshot-1/daemon-dog/instances/run/env/S67_DAEMON ]]
  [[ -L $LAUNCH/run ]]
  SERVICE="$TEST_DIR/snapshot-1/daemon-dog/instances/run"
  PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh daemon-dog
  if [[ -f $SERVICE/down ]]; then
    exit 1
  fi
  printf '%s' changed > "$TEST_DIR/queue-step/env/PAYLOAD"
  "$TEMPLATE" "$TEST_DIR/queue-step" "$TEST_DIR/jobs/daemon-dog"
  PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh daemon-dog
  [[ -f $SERVICE/down ]]
  if [[ -f $SERVICE/env/PAYLOAD ]]; then
    exit 1
  fi
  TEST_STATUS='false false' PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh daemon-dog
  [[ $(< "$SERVICE/env/PAYLOAD") == changed ]]
  if [[ -f $SERVICE/down ]]; then
    exit 1
  fi
  rm -- "$LAUNCH/run"
  TEST_STATUS='false false' PATH="$TEST_BIN:$PATH" RECUR=job env -C "$TEST_DIR/snapshot-1" -- ../jobs/quine/run.sh daemon-dog
  if [[ -d $SERVICE ]]; then
    exit 1
  fi
  ;;
policy)
  SERVICE="$TEST_DIR/snapshot-1/dog/instances/walk"
  mkdir -p -- "$SERVICE" "$TEST_DIR/snapshot-1/dog/data/done" "$TEST_DIR/bin"
  cp --archive -- "$ROOT/base/." "$SERVICE/"
  SERVICE="$(realpath -- "$SERVICE")"
  printf '%s' "$SERVICE" > "$SERVICE/env/S67_WORKING_DIRECTORY"
  cat > "$SERVICE/data/job" << 'EOF'
#!/usr/bin/env bash
printf '%s' "$1"
EOF
  cat > "$TEST_DIR/bin/sleep" << 'EOF'
#!/usr/bin/env bash
printf '%s' "${@: -1}" > ./delay
EOF
  chmod +x -- "$SERVICE/data/job" "$TEST_DIR/bin/sleep"
  TEST_BIN="$(realpath -- "$TEST_DIR/bin")"
  touch -- "$SERVICE/env/S67_DAEMON"
  PATH="$TEST_BIN:$PATH" env -C "$SERVICE" -- ./run walk > "$TEST_DIR/output"
  [[ $(< "$TEST_DIR/output") == walk ]]
  if [[ -f $SERVICE/delay ]]; then
    exit 1
  fi
  rm -- "$SERVICE/data/.pgid"
  env -C "$SERVICE" -- ./finish 7 0 walk > "$TEST_DIR/finish.log"
  ATTEMPT="$(wc -l < "$SERVICE/data/attempt")"
  ((ATTEMPT == 1))
  printf '%s' 0 > "$SERVICE/env/S67_DAEMON"
  PATH="$TEST_BIN:$PATH" env -C "$SERVICE" -- ./run walk > "$TEST_DIR/output"
  [[ $(< "$SERVICE/delay") == "$(< "$SERVICE/env/S67_RESTART_SEC")" ]]
  rm -- "$SERVICE/data/.pgid"
  env -C "$SERVICE" -- ./finish 0 0 walk > "$TEST_DIR/finish.log"
  ATTEMPT="$(wc -l < "$SERVICE/data/attempt")"
  ((ATTEMPT == 0))
  rm -- "$SERVICE/env/S67_DAEMON" "$SERVICE/delay"
  PATH="$TEST_BIN:$PATH" env -C "$SERVICE" -- ./run walk > "$TEST_DIR/output"
  if [[ -f $SERVICE/delay ]]; then
    exit 1
  fi
  rm -- "$SERVICE/data/.pgid"
  ln -s -- /dev/null "$SERVICE/data/launch"
  if env -C "$SERVICE" -- ./finish 7 0 walk > "$TEST_DIR/finish.log"; then
    exit 1
  else
    [[ $? == 125 ]]
  fi
  [[ -f $TEST_DIR/snapshot-1/dog/data/done/walk ]]
  if [[ -L $SERVICE/data/launch ]]; then
    exit 1
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
