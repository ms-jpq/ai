#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if (($# == 0)); then
  printf '%s\n' ctl snapshots publication templates execution queues policy logger runtime lifecycle | shuf | xargs --max-procs=0 --max-args=1 -- "$0"
  exit
fi
trap 'printf "%s [%s]:%s: %s\n" "$0" "$1" "$LINENO" "$BASH_COMMAND" >&2' ERR

ROOT="${0%.test.sh}"
DL="$ROOT/../dl"
TEMPLATE="$DL/jobs/dispatch/data/service-template.sh"
mkdir -p -- "$ROOT/../../var/tmp"
TEST_DIR="$(mktemp -d -- "$ROOT/../../var/tmp/s6-test.XXXXXX")"
TEST_DIR="$(realpath -- "$TEST_DIR")"
STATE="$TEST_DIR/snapshot-1"
JOBS="$TEST_DIR/jobs"
QUINE=(env -C "$STATE" -- "$JOBS/quine/run.sh")
trap 'rm -fr -- "$TEST_DIR"' EXIT
mkdir -- "$STATE"
cp --archive -- "$ROOT/." "$TEST_DIR/"

case "$1" in
ctl)
  RUNTIME="$TEST_DIR/runtime"
  mkdir -p -- "$TEST_DIR/bin" "$RUNTIME/log-archive" "$RUNTIME/failed"
  printf '%s' retained > "$RUNTIME/log-archive/existing.log"
  printf '%s' retained > "$RUNTIME/failed/existing"
  cat > "$TEST_DIR/bin/ps" << 'BASH'
#!/usr/bin/env bash
printf 'parent start time\n'
BASH
  cat > "$TEST_DIR/bin/s6-svscan" << 'BASH'
#!/usr/bin/env bash
printf '%s\n' "${@: -1}"
printf 'inherited descriptor\n' >&67
BASH
  chmod +x -- "$TEST_DIR/bin/"{ps,s6-svscan}
  for _ in 1 2; do
    PATH="$TEST_DIR/bin:$PATH" "$TEST_DIR/ctl.sh" start "$RUNTIME" "$TEST_DIR" 67
    for DIR in services log log-archive failed; do
      [[ -d $RUNTIME/$DIR ]]
    done
    [[ -d $RUNTIME/services/quine/instances/- ]]
    [[ -d $RUNTIME/services/watchdog/instances/67 ]]
    [[ $(< "$RUNTIME/services/watchdog/data/launch/67") == 'parent start time' ]]
    [[ $(< "$RUNTIME/log-archive/existing.log") == retained ]]
    [[ $(< "$RUNTIME/failed/existing") == retained ]]
  done
  COUNT="$(grep --fixed-strings --count "$RUNTIME/services" "$RUNTIME/log/s6.log")"
  [[ $COUNT == 2 ]]
  COUNT="$(grep --fixed-strings --count 'inherited descriptor' "$RUNTIME/log/s6.log")"
  [[ $COUNT == 2 ]]
  "$TEST_DIR/ctl.sh" stop "$TEST_DIR/absent"
  if [[ -e $TEST_DIR/absent ]]; then
    exit 1
  fi
  ;;
logger)
  for INSTANCE in walk log; do
    SERVICE="$STATE/dog/instances/$INSTANCE"
    mkdir -p -- "$SERVICE"
    cp --archive -- "$ROOT/base/." "$SERVICE/"
    mkdir -p -- "$STATE/dog/data/done"
    printf '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
    cat > "$SERVICE/data/job" << 'BASH'
#!/usr/bin/env bash
printf 'ran\n' > "${0%/*}/ran"
printf 'command stdout\n'
printf 'command stderr\n' >&2
exit "${TEST_JOB_STATUS:-0}"
BASH
    chmod +x -- "$SERVICE/data/job"
    for STATUS in 0 67; do
      ACTUAL=0
      TEST_JOB_STATUS="$STATUS" S9_WORKING_DIRECTORY="$TEST_DIR" env -C "$SERVICE" -- ./run "$INSTANCE" > "$TEST_DIR/output" || ACTUAL=$?
      [[ $ACTUAL == "$STATUS" ]]
      [[ -s $SERVICE/data/.pgid ]]
      if [[ -s $TEST_DIR/output ]]; then
        exit 1
      fi
      rm -- "$SERVICE/data/.pgid"
      env -C "$SERVICE" -- ./finish "$STATUS" 0 "$INSTANCE" | env -C "$SERVICE/log" -- ./run 3> "$TEST_DIR/ready" 67>&1 | s6-log -b -l 0 -- T 1 >> "$TEST_DIR/log/s6.log"
      diff --unified -- <(printf '\n') "$TEST_DIR/ready"
      grep --quiet --fixed-strings "dog@$INSTANCE status=$STATUS, signal=0" "$TEST_DIR/log/s6.log"
    done
    if [[ -e $TEST_DIR/log/dog/$INSTANCE.log ]]; then
      exit 1
    fi
    ARCHIVES=("$TEST_DIR/log-archive/dog/$INSTANCE."*.log "$TEST_DIR/failed/dog/$INSTANCE."*/log)
    [[ ${#ARCHIVES[@]} == 2 ]]
    for ARCHIVE in "${ARCHIVES[@]}"; do
      for STREAM in stdout stderr; do
        COUNT="$(grep --fixed-strings --count "dog@$INSTANCE command $STREAM" "$ARCHIVE")"
        [[ $COUNT == 1 ]]
      done
      if grep --quiet --fixed-strings 'status=' "$ARCHIVE"; then
        exit 1
      fi
    done
    FAILED=("$TEST_DIR/failed/dog/$INSTANCE."*)
    [[ ${#FAILED[@]} == 1 ]]
    [[ $(< "${FAILED[0]}/exit_status") == 67 ]]
    [[ $(< "${FAILED[0]}/signal") == 0 ]]
  done
  if grep --quiet --fixed-strings 'command stdout' "$TEST_DIR/log/s6.log"; then
    exit 1
  fi
  env -C "$SERVICE" -- ./finish 256 15 "$INSTANCE" > "$TEST_DIR/finish.log"
  FAILED=("$TEST_DIR/failed/dog/$INSTANCE."*)
  [[ ${#FAILED[@]} == 2 ]]
  [[ $(< "${FAILED[1]}/exit_status") == 256 ]]
  [[ $(< "${FAILED[1]}/signal") == 15 ]]
  [[ -f ${FAILED[1]}/log ]]

  rm -- "$SERVICE/data/attempt" "$SERVICE/data/ran"
  if S9_WORKING_DIRECTORY="$TEST_DIR/missing" env -C "$SERVICE" -- ./run "$INSTANCE" > "$TEST_DIR/output"; then
    exit 1
  fi
  if [[ -e $SERVICE/data/ran ]]; then
    exit 1
  fi
  [[ -s $TEST_DIR/output ]]
  if [[ -e $TEST_DIR/log/dog/$INSTANCE.log ]]; then
    exit 1
  fi

  mkdir -p -- "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/tee" << 'BASH'
#!/usr/bin/env bash
ulimit -f 0
trap '' XFSZ
exec -- "${TEST_TEE?}" "$@"
BASH
  chmod +x -- "$TEST_DIR/bin/tee"
  TEST_TEE="$(command -v -- tee)"
  export TEST_TEE
  if PATH="$TEST_DIR/bin:$PATH" S9_WORKING_DIRECTORY="$TEST_DIR" env -C "$SERVICE" -- ./run "$INSTANCE" > "$TEST_DIR/output"; then
    exit 1
  fi
  [[ -f $SERVICE/data/ran ]]
  ;;
runtime)
  SERVICE="$STATE/dog/instances/walk"
  mkdir -p -- "$SERVICE" "$STATE/dog/data/done"
  cp --archive -- "$ROOT/base/." "$SERVICE/"
  printf '%s' "$SERVICE" > "$SERVICE/env/S9_WORKING_DIRECTORY"
  printf '%s' 1s > "$SERVICE/env/S9_RUNTIME_MAX_SEC"
  cat > "$SERVICE/data/job" << 'BASH'
#!/usr/bin/env bash
if [[ -n ${RECUR:-} ]]; then exit 67; fi
sleep 30 &
printf '%s' "$!" > child
exit 0
BASH
  chmod +x -- "$SERVICE/data/job"
  trap '
    if [[ -f $SERVICE/data/.pgid ]]; then
      kill -KILL -- "-$(< "$SERVICE/data/.pgid")" 2> /dev/null || true
    fi
    rm -fr -- "$TEST_DIR"
  ' EXIT
  START="$SECONDS"
  STATUS=0
  timeout --foreground 5s s6-setsid -i env -C "$SERVICE" -- ./run walk > "$TEST_DIR/output" || STATUS=$?
  [[ $STATUS == 124 ]]
  ((SECONDS - START < 4))
  [[ -s $SERVICE/child ]]
  CHILD="$(< "$SERVICE/child")"
  kill -0 -- "$CHILD"
  STATUS=0
  env -C "$SERVICE" -- ./finish 124 0 walk > "$TEST_DIR/finish.log" || STATUS=$?
  [[ $STATUS == 125 ]]
  timeout --foreground 2s bash -s -- "$CHILD" << 'BASH'
while kill -0 "$1" 2>/dev/null; do sleep 0.02; done
BASH
  [[ -f $STATE/dog/data/done/walk ]]
  ;;
lifecycle)
  STEP="$TEST_DIR/steps/dog"
  JOB="$JOBS/dog"
  SERVICE="$STATE/dog/instances/walk"
  WAIT=(timeout --foreground 15s bash -c 'until test "$@"; do sleep 0.05; done' --)
  export S9_WORKING_DIRECTORY="$TEST_DIR"
  mkdir -p -- "$STEP/env" "$STEP/data" "$JOBS/keeper/env"
  printf '%s' 10 > "$TEST_DIR/base/env/S9_RUNTIME_MAX_SEC"
  cat > "$STEP/run.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
CODE=old
printf '%s:%s:%s\n' "$CODE" "$PAYLOAD" "$(< "${0%/*}/value")" > "$S9_WORKING_DIRECTORY/started-$PAYLOAD"
while ! [[ -f $S9_WORKING_DIRECTORY/release-$PAYLOAD ]]; do sleep 0.05; done
printf '%s\n' "$CODE" > "$S9_WORKING_DIRECTORY/finished-$PAYLOAD"
BASH
  chmod +x -- "$STEP/run.sh"
  printf '%s' 60 | tee "$STEP/env/S9_ON_UNIT_INACTIVE_SEC" > "$JOBS/keeper/env/S9_ON_UNIT_INACTIVE_SEC"
  printf '%s' one > "$STEP/env/PAYLOAD"
  printf '%s' old-data > "$STEP/data/value"
  "$TEMPLATE" "$STEP" "$JOB"
  ln -s -- /dev/null "$STEP/launch/walk"
  RECUR=bootstrap "${QUINE[@]}" quine
  cat > "$JOBS/keeper/run.sh" << 'BASH'
#!/usr/bin/env bash
exit 0
BASH
  chmod +x -- "$JOBS/keeper/run.sh"
  RECUR=seed "${QUINE[@]}" keeper parent
  mkdir -p -- "$STATE/keeper/data/launch"
  ln -s -- /dev/null "$STATE/keeper/data/launch/parent"

  s6-svscan -- "$STATE" > "$TEST_DIR/scan.log" 67>&1 2>&1 &
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
  RECUR=job s6-setlock -t 6000 -- "$STATE/.reconcile.lock" "${QUINE[@]}" dog
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
  ln -sTnfr -- "$JOBS/quine" "$JOBS/quine-2"
  ln -sTnf -- /dev/null "$JOBS/quine/data/null"

  RECUR=bootstrap "${QUINE[@]}" quine
  RECUR=seed env -C "$TEST_DIR/snapshot-2" -- ../jobs/quine-2/run.sh quine-2 -
  RECUR=seed env -C "$TEST_DIR/snapshot-3" -- ../snapshot-1/quine/instances/-/data/job quine -

  [[ -d $TEST_DIR/snapshot-2/quine-2/template ]]
  if [[ -L $TEST_DIR/snapshot-2/quine-2/template ]]; then
    exit 1
  fi
  LINK="$(readlink -- "$STATE/quine/template/data/null")"
  [[ -L $STATE/quine/template/data/null ]]
  [[ $LINK == /dev/null ]]

  diff --recursive --no-dereference --unified --from-file="$STATE/quine" -- "$TEST_DIR/snapshot-2/quine-2" "$TEST_DIR/snapshot-3/quine"
  ;;

publication)
  mkdir -p -- "$TEST_DIR/bin" "$TEST_DIR/old/data/launch" "$TEST_DIR/new/data/launch"
  for REVISION in old new; do
    printf '#!/usr/bin/env bash\nprintf "%s\\n"\n' "$REVISION" > "$TEST_DIR/$REVISION/run.sh"
    chmod +x -- "$TEST_DIR/$REVISION/run.sh"
    ln -s -- "/$REVISION" "$TEST_DIR/$REVISION/data/launch/walk"
  done
  ln -s -- "$TEST_DIR/old" "$JOBS/dog"
  cat > "$TEST_DIR/bin/control" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
case "${0##*/}" in
s6-svwait)
  ln -sTnf -- "$TEST_ROOT/new" "$TEST_ROOT/jobs/dog"
  ;;
s6-instance-create)
  cp --archive -- "${@: -2:1}/template" "${@: -2:1}/instances/${@: -1}"
  ln -s -- "../instances/${@: -1}" "${@: -2:1}/instance/${@: -1}"
  ;;
s6-instance-delete)
  if [[ ${TEST_DELETE_STATUS:-0} != 0 ]]; then
    exit "$TEST_DELETE_STATUS"
  fi
  rm -f -- "${@: -2:1}/instance/${@: -1}"
  rm -fr -- "${@: -2:1}/instances/${@: -1}"
  ;;
s6-svstat)
  printf 'false false\n'
  ;;
esac
BASH
  chmod +x -- "$TEST_DIR/bin/control"
  for COMMAND in s6-svok s6-svwait s6-svc s6-instance-control s6-instance-create s6-instance-delete s6-svstat; do
    ln -s -- control "$TEST_DIR/bin/$COMMAND"
  done
  RECONCILE=(env "PATH=$TEST_DIR/bin:$PATH" "TEST_ROOT=$TEST_DIR" RECUR=job "${QUINE[@]}" dog)
  "${RECONCILE[@]}"
  SERVICE="$STATE/dog/instances/walk"
  diff --unified -- "$TEST_DIR/old/run.sh" "$SERVICE/data/job"
  TARGET="$(readlink -- "$SERVICE/data/launch")"
  [[ $TARGET == /old ]]
  [[ -L $TEST_DIR/new/data/launch/walk ]]
  if [[ -L $TEST_DIR/old/data/launch/walk ]]; then exit 1; fi

  touch -- "$STATE/dog/data/done/walk"
  if TEST_DELETE_STATUS=111 "${RECONCILE[@]}"; then exit 1; fi
  [[ -d $SERVICE ]]
  [[ -f $STATE/dog/data/done/walk ]]
  [[ -L $TEST_DIR/new/data/launch/walk ]]
  "${RECONCILE[@]}"
  diff --unified -- "$TEST_DIR/new/run.sh" "$SERVICE/data/job"
  TARGET="$(readlink -- "$SERVICE/data/launch")"
  [[ $TARGET == /new ]]
  if [[ -f $STATE/dog/data/done/walk ]]; then exit 1; fi

  printf '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
  "${RECONCILE[@]}"
  if [[ -d $SERVICE ]]; then exit 1; fi
  ;;
templates)
  cp --archive -- "$DL/examples" "$TEST_DIR/examples"
  for JOB in dog lil; do
    SERVICE="$STATE/$JOB/instances/-"
    "$TEMPLATE" "$TEST_DIR/examples/$JOB" "$JOBS/$JOB"
    [[ -L $JOBS/$JOB ]]
    RECUR=seed "${QUINE[@]}" "$JOB" -
    diff --unified -- "$DL/examples/$JOB/run.sh" "$SERVICE/data/command"
    diff --unified -- "$DL/jobs/dispatch/data/step.sh" "$SERVICE/data/job"
    EXPECTED_RECORDS="$(realpath -- "$TEST_DIR/examples/$JOB/records")"
    [[ $(< "$SERVICE/env/S9_RECORDS_DIR") == "$EXPECTED_RECORDS" ]]
    if [[ -e $JOBS/$JOB/data/records ]] || [[ -L $JOBS/$JOB/data/records ]]; then
      exit 1
    fi
    for ENV in "$DL/examples/$JOB/env/"*; do
      diff --unified -- "$ENV" "$SERVICE/env/${ENV##*/}"
    done
  done
  ;;

execution)
  STEP="$TEST_DIR/steps/dog"
  mkdir -p -- "$STEP/data/inbox"
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
    ln -sTnf -- "$INPUT" "$STEP/data/inbox/$DEPENDENCY"
  done
  cat > "$STEP/run.sh" << 'BASH'
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
BASH
  chmod +x -- "$STEP/run.sh"
  cat > "$STEP/dispatch.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
[[ -d records ]]
[[ -f $1/command ]]
[[ -d $1/inbox ]]
[[ -d $1/launch ]]
[[ -z ${RECUR:-} ]]
ln -s -- /dev/null "$1/launch/walk"
BASH
  chmod +x -- "$STEP/dispatch.sh"
  S9_JOBS_DIR="$JOBS" "$DL/jobs/dispatch/run.sh" "$TEST_DIR/steps"
  [[ -L $JOBS/dog/data/launch/walk ]]
  cat > "$STEP/run.sh" << 'BASH'
exit 99
BASH

  for INSTANCE in walk feed; do
    RECUR=seed "${QUINE[@]}" dog "$INSTANCE"
    SERVICE="$STATE/dog/instances/$INSTANCE"
    PAYLOAD=first RESULT=0 s6-envdir -- "$SERVICE/env" "$SERVICE/data/job" "$INSTANCE" 2> "$TEST_DIR/stderr"
    [[ $(< "$TEST_DIR/stderr") == diagnostic ]]
    [[ $(< "$SERVICE/data/outbox/stdout") == "$INSTANCE:first" ]]
    [[ $(< "$SERVICE/data/outbox/exit_status") == 0 ]]
    [[ -d $STEP/records/$INSTANCE/latest/input ]]
  done

  SERVICE="$STATE/dog/instances/walk"
  VERSIONS="$STEP/records/walk"
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
  [[ $(< "$STEP/records/walk/latest/output/stdout") == walk:second ]]
  [[ $(< "$STEP/records/feed/latest/output/stdout") == feed:first ]]
  ;;

queues)
  STEP="$TEST_DIR/queue-step"
  JOB="$JOBS/queue-dog"
  LAUNCH="$JOB/data/launch"
  MANAGER="$STATE/queue-dog"
  mkdir -p -- "$STEP" "$TEST_DIR/bin"
  cp --preserve=mode -- "$DL/examples/dog/run.sh" "$STEP/run.sh"
  cat > "$TEST_DIR/bin/s6-instance-create" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
MANAGER="${@: -2:1}"
INSTANCE="${@: -1}"
if [[ $INSTANCE == rejected ]]; then
  exit 67
fi
mkdir -p -- "$MANAGER/instances/$INSTANCE"
cp --archive -- "$MANAGER/template/." "$MANAGER/instances/$INSTANCE/"
BASH
  cat > "$TEST_DIR/bin/noop" << 'BASH'
#!/usr/bin/env bash
exit 0
BASH
  cat > "$TEST_DIR/bin/s6-svstat" << 'BASH'
#!/usr/bin/env bash
printf '%s\n' "${TEST_STATUS:-true}"
BASH
  cat > "$TEST_DIR/bin/s6-instance-delete" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
rm -fr -- "${@: -2:1}/instances/${@: -1}"
BASH
  chmod +x -- "$TEST_DIR/bin/"{s6-instance-create,s6-instance-delete,s6-svstat,noop}
  for COMMAND in s6-svok s6-svwait s6-svc s6-instance-control; do
    ln -s -- noop "$TEST_DIR/bin/$COMMAND"
  done
  RECONCILE=(env "PATH=$TEST_DIR/bin:$PATH" RECUR=job "${QUINE[@]}")
  for _ in 1 2; do
    "$TEMPLATE" "$STEP" "$JOB"
  done
  ln -s -- /missing/inbox "$LAUNCH/run"
  ln -s -- /dev/null "$LAUNCH/.pending"
  "${RECONCILE[@]}" queue-dog
  [[ -d $MANAGER/instances/run ]]
  [[ -L $MANAGER/instances/run/data/launch ]]
  if [[ -L $LAUNCH/run ]] || [[ -d $MANAGER/instances/.pending ]]; then
    exit 1
  fi
  [[ -L $LAUNCH/.pending ]]

  ln -s -- /dev/null "$LAUNCH/rejected"
  if "${RECONCILE[@]}" queue-dog; then
    exit 1
  fi
  [[ -L $LAUNCH/rejected ]]
  "$TEMPLATE" "$STEP" "$JOB"
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

  mkdir -- "$STEP/env"
  printf '%s' 0 > "$STEP/env/S9_ON_UNIT_INACTIVE_SEC"
  rm -- "$LAUNCH/rejected"
  "$TEMPLATE" "$STEP" "$JOBS/daemon-dog"
  "${RECONCILE[@]}" daemon-dog
  [[ $(< "$STATE/daemon-dog/instances/run/env/S9_ON_UNIT_INACTIVE_SEC") == 0 ]]
  [[ -L $LAUNCH/run ]]
  SERVICE="$STATE/daemon-dog/instances/run"
  "${RECONCILE[@]}" daemon-dog
  if [[ -f $SERVICE/down ]]; then
    exit 1
  fi
  printf '%s' changed > "$STEP/env/PAYLOAD"
  "$TEMPLATE" "$STEP" "$JOBS/daemon-dog"
  "${RECONCILE[@]}" daemon-dog
  [[ -f $SERVICE/down ]]
  if [[ -f $SERVICE/env/PAYLOAD ]]; then
    exit 1
  fi
  TEST_STATUS='false false' "${RECONCILE[@]}" daemon-dog
  [[ $(< "$SERVICE/env/PAYLOAD") == changed ]]
  if [[ -f $SERVICE/down ]]; then
    exit 1
  fi
  rm -- "$LAUNCH/run"
  TEST_STATUS='false false' "${RECONCILE[@]}" daemon-dog
  if [[ -d $SERVICE ]]; then
    exit 1
  fi
  ;;
policy)
  SERVICE="$STATE/dog/instances/walk"
  mkdir -p -- "$SERVICE" "$STATE/dog/data/done" "$TEST_DIR/bin"
  cp --archive -- "$ROOT/base/." "$SERVICE/"
  printf '%s' "$SERVICE" > "$SERVICE/env/S9_WORKING_DIRECTORY"
  printf '%s' 2 > "$SERVICE/env/S9_RESTART_SEC"
  cat > "$SERVICE/data/job" << 'BASH'
#!/usr/bin/env bash
printf '%s' "$1"
BASH
  cat > "$TEST_DIR/bin/sleep" << 'BASH'
#!/usr/bin/env bash
printf '%s' "${@: -1}" > ./delay
BASH
  chmod +x -- "$SERVICE/data/job" "$TEST_DIR/bin/sleep"
  TEST_BIN="$(realpath -- "$TEST_DIR/bin")"
  ln -s -- /dev/null "$SERVICE/data/launch"
  trap 'printf "policy:%s interval=%s cap=%s status=%s delay=%s exit=%s attempts=%s: %s\n" "$LINENO" "$INTERVAL" "$CAP" "$STATUS" "$DELAY" "$EXPECTED_EXIT" "$EXPECTED_ATTEMPTS" "$BASH_COMMAND" >&2' ERR
  while read -r INTERVAL CAP STATUS DELAY EXPECTED_EXIT EXPECTED_ATTEMPTS; do
    printf '%s' "$INTERVAL" > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
    printf '%s' "${CAP#-}" > "$SERVICE/env/S9_RESTART_MAX_DELAY_SEC"
    rm -f -- "$SERVICE/delay"
    PATH="$TEST_BIN:$PATH" env -C "$SERVICE" -- ./run walk > "$TEST_DIR/output"
    if [[ -s $TEST_DIR/output ]]; then
      exit 1
    fi
    grep --quiet --fixed-strings 'dog@walk walk' "$TEST_DIR/log/dog/walk.log"
    ACTUAL_DELAY=none
    if [[ -f $SERVICE/delay ]]; then ACTUAL_DELAY="$(< "$SERVICE/delay")"; fi
    [[ $ACTUAL_DELAY == "$DELAY" ]]
    rm -- "$SERVICE/data/.pgid"
    EXIT_STATUS=0
    env -C "$SERVICE" -- ./finish "$STATUS" 0 walk > "$TEST_DIR/finish.log" || EXIT_STATUS=$?
    ((EXIT_STATUS == EXPECTED_EXIT))
    ATTEMPT="$(wc -l < "$SERVICE/data/attempt")"
    ((ATTEMPT == EXPECTED_ATTEMPTS))
    if ((EXIT_STATUS == 0)); then [[ -L $SERVICE/data/launch ]]; fi
  done << 'EOF'
60 - 7 none 0 1
60 - 7 2 0 2
60 - 0 4 0 0
60 - 0 60 0 0
0 - 7 0 0 1
0 - 7 2 0 2
0 - 7 4 0 3
0 - 0 4 0 0
0 - 0 0 0 0
0 3 7 0 0 1
0 3 7 2 0 2
0 3 0 3 0 0
0 1 7 0 0 1
0 1 0 1 0 0
0 0 7 0 0 1
0 0 0 0 0 0
-1 - 7 none 125 0
-1 - 0 none 125 0
EOF
  [[ -f $STATE/dog/data/done/walk ]]
  if [[ -L $SERVICE/data/launch ]]; then
    exit 1
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
