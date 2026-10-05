#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if (($# == 0)); then
  printf '%s\n' ctl snapshots p-cp publication templates queues policy logger runtime lifecycle dataflow | shuf | xargs --max-procs=0 --max-args=1 -- "$0"
  exit
fi
trap 'printf "%s [%s]:%s: %s\n" "$0" "$1" "$LINENO" "$BASH_COMMAND" >&2' ERR

ROOT="${0%.test.sh}"
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
dataflow)
  shopt -u failglob
  FLOW="$TEST_DIR/libexec/dataflow.sh"
  RUNTIME="$TEST_DIR/runtime"
  SERVICES="$RUNTIME/services"
  INPUT="$TEST_DIR/input"
  mkdir -p -- "$RUNTIME" "$INPUT"
  FINISH="$TEST_DIR/finish.sh"
  cat > "$FINISH" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="${0%/*}"
SERVICE="$ROOT/runtime/services/$1/instances/$2"
mkdir -p -- "$SERVICE"
rsync --archive --copy-unsafe-links -- "$ROOT/base/" "$SERVICE/"
printf '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
env -C "$SERVICE" -- ./finish "$3" "$4" "$2" > "$ROOT/finish.log"
"$ROOT/libexec/dataflow.sh" project "$ROOT/runtime"
BASH
  chmod +x -- "$FINISH"
  for JOB in producer-1 producer-2 consumer sink; do
    mkdir -p -- "$JOBS/$JOB/data/launch" "$SERVICES/$JOB/template" "$SERVICES/$JOB/instances"
    printf '%s' "$JOB-v1" > "$SERVICES/$JOB/template/.sum"
  done
  mkdir -p -- "$JOBS/consumer/data/wants" "$JOBS/sink/data/wants"
  ln -sTnfr -- "$JOBS/producer-1" "$JOBS/consumer/data/wants/first"
  ln -sTnfr -- "$JOBS/producer-2" "$JOBS/consumer/data/wants/second"
  ln -sTnfr -- "$JOBS/consumer" "$JOBS/sink/data/wants/result"
  for JOB in consumer sink; do
    mkdir -p -- "$SERVICES/$JOB/template/data/wants"
    for WANT in "$JOBS"/"$JOB"/data/wants/*; do
      ln -sTnfr -- "$WANT" "$SERVICES/$JOB/template/data/wants/${WANT##*/}"
    done
  done
  for JOB in producer-1 producer-2; do
    HASH="$(printf '%s' "$JOB" | b3sum)"
    HASH="${HASH%% *}"
    ln -sTnfr -- "$INPUT" "$JOBS/$JOB/data/launch/$HASH"
    "$FLOW" prepare "$RUNTIME" "$JOB" "$HASH" "$INPUT"
    mkdir -- "$RUNTIME/live/$JOB@$HASH/outputs/"{A,B}
    printf '%s' "$JOB" > "$RUNTIME/live/$JOB@$HASH/log"
    "$FINISH" "$JOB" "$HASH" 0 0
  done
  "$FLOW" compile "$RUNTIME" "$JOBS" "$SERVICES"
  REQUESTS=("$SERVICES/consumer/data/launch/"*)
  [[ ${#REQUESTS[@]} == 4 ]]
  [[ -L $RUNTIME/graph/wanted-by/producer-1/consumer ]]
  mkdir -p -- "$SERVICES/consumer/data/.exited"
  for REQUEST in "${REQUESTS[@]}"; do
    HASH="${REQUEST##*/}"
    SERVICE="$SERVICES/consumer/instances/$HASH"
    mkdir -p -- "$SERVICE"
    rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
    cat > "$SERVICE/data/.run" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
test -d ./inputs/producer-1
test -d ./inputs/producer-2
mkdir -- ./outputs/result
printf '%s' "$1" > ./outputs/result/value
BASH
    chmod +x -- "$SERVICE/data/.run"
    TARGET="$(realpath -- "$REQUEST")"
    ln -sTnf -- "$TARGET" "$REQUEST"
    mv -- "$REQUEST" "$SERVICES/consumer/instances/$HASH/data/launch"
    "$FLOW" prepare "$RUNTIME" consumer "$HASH" "$SERVICES/consumer/instances/$HASH/data/launch"
    TELEMETRY=("$RUNTIME/live/consumer@$HASH/telemetry/"*)
    [[ ${#TELEMETRY[@]} == 2 ]]
    if [[ -L $RUNTIME/live/consumer@$HASH/inputs ]]; then exit 1; fi
    [[ -d $RUNTIME/live/consumer@$HASH/inputs/producer-1 ]]
    TARGET="$(readlink -- "$RUNTIME/live/consumer@$HASH/inputs/producer-1")"
    [[ $TARGET == ../telemetry/1-producer-1@*/outputs/* ]]
    if [[ -e $RUNTIME/live/consumer@$HASH/inputs/first ]]; then exit 1; fi
    "$FLOW" project "$RUNTIME"
    if [[ -L $REQUEST ]]; then exit 1; fi
    S9_WORKING_DIRECTORY="$RUNTIME/live/consumer@$HASH" env -C "$SERVICE" -- ./run "$HASH" > "$TEST_DIR/output"
    rm -- "$SERVICE/data/.pgid"
    STATUS=0
    env -C "$SERVICE" -- ./finish 0 0 "$HASH" > "$TEST_DIR/output" || STATUS=$?
    [[ $STATUS == 125 ]]
    "$FLOW" project "$RUNTIME"
    RECORD="$(realpath -- "$RUNTIME/dead/consumer/$HASH.latest-succ")"
    TARGET="$(readlink -- "$RUNTIME/dead/consumer/$HASH.latest-succ")"
    [[ $TARGET == "${RECORD##*/}" ]]
    [[ $(< "$RECORD/outputs/result/value") == "$HASH" ]]
    if [[ -L $RECORD/inputs ]]; then exit 1; fi
    rm -fr -- "$RUNTIME/graph/cartesian/consumer/$HASH"
    [[ -d $RECORD/inputs/producer-1 ]]
    [[ -d $RECORD/inputs/producer-2 ]]
    TARGET="$(readlink -- "$RECORD/inputs/producer-1")"
    [[ $TARGET == ../telemetry/1-producer-1@*/outputs/* ]]
    [[ -f $SERVICES/consumer/data/.exited/$HASH ]]
    rm -fr -- "$SERVICES/consumer/instances/$HASH"
  done
  REQUESTS=("$SERVICES/sink/data/launch/"*)
  [[ ${#REQUESTS[@]} == 4 ]]
  for REQUEST in "${REQUESTS[@]}"; do
    HASH="${REQUEST##*/}"
    "$FLOW" prepare "$RUNTIME" sink "$HASH" "$REQUEST"
    TELEMETRY=("$RUNTIME/live/sink@$HASH/telemetry/"*)
    [[ ${#TELEMETRY[@]} == 3 ]]
    "$FINISH" sink "$HASH" 67 0
    rm -- "$REQUEST"
  done
  printf '%s\0' project project project | xargs --null --max-procs=0 -I '{}' -- "$FLOW" '{}' "$RUNTIME"
  REQUESTS=("$SERVICES/sink/data/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  printf '%s' consumer-v2 > "$SERVICES/consumer/template/.sum"
  "$FLOW" compile "$RUNTIME" "$JOBS" "$SERVICES"
  REQUESTS=("$SERVICES/consumer/data/launch/"*)
  [[ ${#REQUESTS[@]} == 4 ]]
  rm -- "${REQUESTS[@]}"
  printf '%s' consumer-v1 > "$SERVICES/consumer/template/.sum"
  "$FLOW" compile "$RUNTIME" "$JOBS" "$SERVICES"
  REQUESTS=("$SERVICES/consumer/data/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  HASH="$(printf '%s' producer-1 | b3sum)"
  HASH="${HASH%% *}"
  PREVIOUS="$(realpath -- "$RUNTIME/dead/producer-1/$HASH.latest-succ")"
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  "$FINISH" producer-1 "$HASH" 67 0
  [[ $RUNTIME/dead/producer-1/$HASH.latest-succ -ef $PREVIOUS ]]
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  mkdir -- "$RUNTIME/live/producer-1@$HASH/outputs/A"
  "$FINISH" producer-1 "$HASH" 0 0
  REQUESTS=("$SERVICES/consumer/data/launch/"*)
  [[ ${#REQUESTS[@]} == 2 ]]
  for REQUEST in "${REQUESTS[@]}"; do
    [[ -d $REQUEST/producer-1 ]]
    [[ ${REQUEST##*/} != "${PREVIOUS##*/}" ]]
  done
  rm -- "${REQUESTS[@]}"
  printf '%s' sink-v2 > "$SERVICES/sink/template/.sum"
  "$FLOW" compile "$RUNTIME" "$JOBS" "$SERVICES"
  REQUESTS=("$SERVICES/sink/data/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  "$FINISH" producer-1 "$HASH" 0 0
  REQUESTS=("$SERVICES/consumer/data/launch/"*)
  for REQUEST in "${REQUESTS[@]}"; do rm -- "$REQUEST"; done
  "$FLOW" project "$RUNTIME"
  REQUESTS=("$SERVICES/consumer/data/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  "$FLOW" prepare "$RUNTIME" recovery record "$INPUT"
  mkdir -- "$RUNTIME/live/recovery@record/outputs/row"
  "$FINISH" recovery record 0 0
  RECORD="$(realpath -- "$RUNTIME/dead/recovery/record.latest-succ")"
  rm -- "$RUNTIME/graph/completed/recovery/record"
  mkdir -- "$RUNTIME/live/recovery@record"
  cp -- "$RECORD/"{exit_status,signal} "$RUNTIME/live/recovery@record/"
  printf '%s' "$RECORD" > "$RUNTIME/live/recovery@record/.record"
  printf '%s' "$SERVICES/recovery/instances/record" > "$RUNTIME/live/recovery@record/.service"
  ln -sTnfr -- "$RUNTIME/live/recovery@record" "$RUNTIME/graph/pending/recovery/record"
  [[ -L $RUNTIME/graph/pending/recovery/record ]]
  "$FLOW" compile "$RUNTIME" "$JOBS" "$SERVICES"
  [[ $RUNTIME/graph/completed/recovery/record -ef $RECORD ]]
  [[ -d $RUNTIME/dead/recovery/record.latest-succ/outputs/row ]]
  if [[ -L $RUNTIME/graph/pending/recovery/record ]]; then exit 1; fi
  mkdir -p -- "$JOBS/producer-1/data/wants"
  ln -sTnfr -- "$JOBS/sink" "$JOBS/producer-1/data/wants/cycle"
  mkdir -p -- "$SERVICES/producer-1/template/data/wants"
  ln -sTnfr -- "$JOBS/sink" "$SERVICES/producer-1/template/data/wants/cycle"
  if "$FLOW" compile "$RUNTIME" "$JOBS" "$SERVICES" > "$TEST_DIR/output" 2>&1; then exit 1; fi
  grep --quiet 'Dependency cycle' "$TEST_DIR/output"
  ;;
ctl)
  RUNTIME="$TEST_DIR/runtime"
  mkdir -p -- "$TEST_DIR/bin" "$RUNTIME/dead" "$RUNTIME/failed"
  printf '%s' retained > "$RUNTIME/dead/existing.log"
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
    for DIR in services live dead failed; do
      [[ -d $RUNTIME/$DIR ]]
    done
    [[ -d $RUNTIME/services/quine/instances/- ]]
    [[ -d $RUNTIME/services/watchdog/instances/67 ]]
    [[ $(< "$RUNTIME/services/watchdog/data/launch/67") == 'parent start time' ]]
    [[ $(< "$RUNTIME/dead/existing.log") == retained ]]
    [[ $(< "$RUNTIME/failed/existing") == retained ]]
  done
  COUNT="$(grep --fixed-strings --count "$RUNTIME/services" "$RUNTIME/live/s6.log")"
  [[ $COUNT == 2 ]]
  COUNT="$(grep --fixed-strings --count 'inherited descriptor' "$RUNTIME/live/s6.log")"
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
    rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
    mkdir -p -- "$STATE/dog/data/.exited"
    printf '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
    cat > "$SERVICE/data/.run" << 'BASH'
#!/usr/bin/env bash
printf 'ran\n' > "${0%/*}/ran"
printf 'command stdout\n'
printf 'command stderr\n' >&2
exit "${TEST_JOB_STATUS:-0}"
BASH
    chmod +x -- "$SERVICE/data/.run"
    for STATUS in 0 67; do
      ACTUAL=0
      TEST_JOB_STATUS="$STATUS" S9_WORKING_DIRECTORY="$TEST_DIR" env -C "$SERVICE" -- ./run "$INSTANCE" > "$TEST_DIR/output" || ACTUAL=$?
      [[ $ACTUAL == "$STATUS" ]]
      [[ -s $SERVICE/data/.pgid ]]
      if [[ -s $TEST_DIR/output ]]; then
        exit 1
      fi
      rm -- "$SERVICE/data/.pgid"
      env -C "$SERVICE" -- ./finish "$STATUS" 0 "$INSTANCE" | env -C "$SERVICE/log" -- ./run 3> "$TEST_DIR/ready" 67>&1 | s6-log -b -l 0 -- T 1 >> "$TEST_DIR/live/s6.log"
      diff --unified -- <(printf '\n') "$TEST_DIR/ready"
      grep --quiet --fixed-strings -- "dog@$INSTANCE --- exit_status=$STATUS signal=0 ---" "$TEST_DIR/live/s6.log"
    done
    if [[ -e $TEST_DIR/live/dog@$INSTANCE/log ]]; then
      exit 1
    fi
    ARCHIVES=("$TEST_DIR/dead/dog/$INSTANCE."[0-9]*/log)
    [[ ${#ARCHIVES[@]} == 2 ]]
    for ARCHIVE in "${ARCHIVES[@]}"; do
      COUNT="$(grep --count --extended-regexp -- "^[0-9]{4}-[0-9]{2}-[0-9]{2} .*dog@$INSTANCE --- started ---$" "$ARCHIVE")"
      [[ $COUNT == 1 ]]
      for STREAM in stdout stderr; do
        COUNT="$(grep --fixed-strings --count "dog@$INSTANCE command $STREAM" "$ARCHIVE")"
        [[ $COUNT == 1 ]]
      done
      COUNT="$(grep --fixed-strings --count -- '--- exit_status=' "$ARCHIVE")"
      [[ $COUNT == 1 ]]
      grep --quiet --fixed-strings -- "dog@$INSTANCE --- exit_status=$(< "${ARCHIVE%/*}/exit_status") signal=$(< "${ARCHIVE%/*}/signal") ---" "$ARCHIVE"
    done
    DEAD=("$TEST_DIR/dead/dog/$INSTANCE."[0-9]*)
    [[ ${#DEAD[@]} == 2 ]]
    [[ $TEST_DIR/dead/dog/$INSTANCE.latest-succ -ef ${DEAD[0]} ]]
    [[ $(< "${DEAD[0]}/exit_status") == 0 ]]
    [[ $(< "${DEAD[0]}/signal") == 0 ]]
    FAILED=("$TEST_DIR/failed/dog/$INSTANCE."*)
    [[ ${#FAILED[@]} == 1 ]]
    [[ -L ${FAILED[0]} ]]
    [[ ${FAILED[0]} -ef ${DEAD[1]} ]]
    TARGET="$(readlink -- "${FAILED[0]}")"
    if [[ $TARGET == /* ]]; then exit 1; fi
    [[ $(< "${FAILED[0]}/exit_status") == 67 ]]
    [[ $(< "${FAILED[0]}/signal") == 0 ]]
  done
  if grep --quiet --fixed-strings 'command stdout' "$TEST_DIR/live/s6.log"; then
    exit 1
  fi
  env -C "$SERVICE" -- ./finish 256 15 "$INSTANCE" > "$TEST_DIR/finish.log"
  FAILED=("$TEST_DIR/failed/dog/$INSTANCE."*)
  [[ ${#FAILED[@]} == 2 ]]
  [[ $(< "${FAILED[1]}/exit_status") == 256 ]]
  [[ $(< "${FAILED[1]}/signal") == 15 ]]
  [[ -f ${FAILED[1]}/log ]]

  printf '%s' "$TEST_DIR/telemetry" > "$SERVICE/env/S9_DEAD_DIR"
  for STATUS in 0 67; do
    env -C "$SERVICE" -- ./finish "$STATUS" 0 "$INSTANCE" > "$TEST_DIR/finish.log"
  done
  RECORDS=("$TEST_DIR/telemetry/dog/"*)
  [[ ${#RECORDS[@]} == 2 ]]
  for RECORD in "${RECORDS[@]}"; do
    [[ -f $RECORD/log ]]
    [[ $(< "$RECORD/signal") == 0 ]]
  done
  [[ $(< "${RECORDS[0]}/exit_status") == 0 ]]
  [[ $(< "${RECORDS[1]}/exit_status") == 67 ]]
  [[ $TEST_DIR/failed/dog/${RECORDS[1]##*/} -ef ${RECORDS[1]} ]]

  rm -- "$SERVICE/data/attempt" "$SERVICE/data/ran"
  if S9_WORKING_DIRECTORY="$TEST_DIR/missing" env -C "$SERVICE" -- ./run "$INSTANCE" > "$TEST_DIR/output"; then
    exit 1
  fi
  if [[ -e $SERVICE/data/ran ]]; then
    exit 1
  fi
  [[ -s $TEST_DIR/output ]]
  if [[ -e $TEST_DIR/live/dog@$INSTANCE/log ]]; then
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

  rm -- "$SERVICE/data/.pgid"
  printf '%s' -1 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
  printf '%s' blocked > "$TEST_DIR/blocked"
  for FAILURE in archive footer; do
    case "$FAILURE" in
    archive) printf '%s' "$TEST_DIR/blocked" > "$SERVICE/env/S9_DEAD_DIR" ;;
    footer) printf '%s' "$TEST_DIR/footer-records" > "$SERVICE/env/S9_DEAD_DIR" ;;
    *)
      set -x
      exit 2
      ;;
    esac
    ln -sTnfr -- /dev/null "$SERVICE/data/launch"
    if PATH="$TEST_DIR/bin:$PATH" env -C "$SERVICE" -- ./finish 67 0 "$INSTANCE" > "$TEST_DIR/finish.log"; then
      exit 1
    fi
    if [[ -f $STATE/dog/data/.exited/$INSTANCE ]]; then exit 1; fi
    [[ -L $SERVICE/data/launch ]]
    [[ -f $TEST_DIR/live/dog@$INSTANCE/log ]]
  done
  if [[ -d $TEST_DIR/footer-records ]]; then exit 1; fi
  ;;
runtime)
  SERVICE="$STATE/dog/instances/walk"
  mkdir -p -- "$SERVICE" "$STATE/dog/data/.exited"
  rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
  printf '%s' "$SERVICE" > "$SERVICE/env/S9_WORKING_DIRECTORY"
  printf '%s' 1s > "$SERVICE/env/S9_RUNTIME_MAX_SEC"
  cat > "$SERVICE/data/.run" << 'BASH'
#!/usr/bin/env bash
if [[ -n ${RECUR:-} ]]; then exit 67; fi
sleep 30 &
printf '%s' "$!" > child
exit 0
BASH
  chmod +x -- "$SERVICE/data/.run"
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
  [[ -f $STATE/dog/data/.exited/walk ]]
  ;;
lifecycle)
  STEP="$TEST_DIR/steps/dog"
  JOB="$JOBS/dog"
  SERVICE="$STATE/dog/instances/walk"
  WAIT=(timeout --foreground 15s bash -c 'until test "$@"; do sleep 0.05; done' --)
  export S9_WORKING_DIRECTORY="$TEST_DIR"
  mkdir -p -- "$STEP/env" "$STEP/data/launch" "$JOBS/keeper/env"
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
  ln -sTnfr -- "$STEP" "$JOB"
  ln -sTnfr -- /dev/null "$STEP/data/launch/walk"
  RECUR=bootstrap "${QUINE[@]}" quine
  cat > "$JOBS/keeper/run.sh" << 'BASH'
#!/usr/bin/env bash
exit 0
BASH
  chmod +x -- "$JOBS/keeper/run.sh"
  RECUR=seed "${QUINE[@]}" keeper parent
  mkdir -p -- "$STATE/keeper/data/launch"
  ln -sTnfr -- /dev/null "$STATE/keeper/data/launch/parent"

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
      find "$TEST_DIR/live" -type f -exec cat -- {} + >&2
    fi
    rm -fr -- "$TEST_DIR"
    exit "$RESULT"
  ' EXIT

  "${WAIT[@]}" -s "$TEST_DIR/started-one"
  [[ $(< "$TEST_DIR/started-one") == old:one:old-data ]]
  PID="$(s6-svstat -o pid -- "$SERVICE")"
  RECUR=job s6-setlock -t 6000 -- "$STATE/.reconcile.lock" "${QUINE[@]}" dog
  if [[ -f $SERVICE/down ]]; then exit 1; fi
  CURRENT_PID="$(s6-svstat -o pid -- "$SERVICE")"
  [[ $CURRENT_PID == "$PID" ]]

  sed -i -e 's/CODE=old/CODE=new/' -- "$STEP/run.sh"
  printf '%s' two > "$STEP/env/PAYLOAD"
  printf '%s' new-data > "$STEP/data/value"
  "${WAIT[@]}" -s "$TEST_DIR/started-two"
  if [[ -f $TEST_DIR/finished-one ]]; then exit 1; fi
  [[ $(< "$TEST_DIR/started-two") == new:two:new-data ]]

  for ATTEMPT in two three four; do
    case "$ATTEMPT" in
    two) rm -- "$STEP/data/launch/walk" ;;
    three) mv -- "$STEP" "$TEST_DIR/removed-step" ;;
    four) rm -- "$JOB" ;;
    *)
      set -x
      exit 2
      ;;
    esac
    "${WAIT[@]}" ! -d "$SERVICE"
    if [[ -f $TEST_DIR/finished-$ATTEMPT ]]; then exit 1; fi
    case "$ATTEMPT" in
    two)
      printf '%s' three > "$STEP/env/PAYLOAD"
      ln -sTnfr -- /dev/null "$STEP/data/launch/walk"
      "${WAIT[@]}" -s "$TEST_DIR/started-three"
      ;;
    three)
      STEP="$TEST_DIR/removed-step"
      printf '%s' four > "$STEP/env/PAYLOAD"
      ln -sTnfr -- "$STEP" "$JOB"
      "${WAIT[@]}" -s "$TEST_DIR/started-four"
      ;;
    four) ;;
    *)
      set -x
      exit 2
      ;;
    esac
  done
  RECORDS=("$TEST_DIR/dead/dog/"*)
  [[ ${#RECORDS[@]} == 4 ]]
  for RECORD in "${RECORDS[@]}"; do
    [[ -f $RECORD/log ]]
    [[ $(< "$RECORD/exit_status") != 0 ]] || [[ $(< "$RECORD/signal") != 0 ]]
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
  RECUR=seed env -C "$TEST_DIR/snapshot-3" -- ../snapshot-1/quine/instances/-/data/.run quine -

  [[ -d $TEST_DIR/snapshot-2/quine-2/template ]]
  if [[ -L $TEST_DIR/snapshot-2/quine-2/template ]]; then
    exit 1
  fi
  LINK="$(readlink -- "$STATE/quine/template/data/null")"
  [[ -L $STATE/quine/template/data/null ]]
  [[ $LINK == /dev/null ]]

  diff --recursive --no-dereference --unified --from-file="$STATE/quine" -- "$TEST_DIR/snapshot-2/quine-2" "$TEST_DIR/snapshot-3/quine"
  ;;

p-cp)
  PCP="$TEST_DIR/libexec/p-cp.sh"
  SRC="$TEST_DIR/source"
  DST="$TEST_DIR/output/dog"
  mkdir -p -- "$SRC/nested" "$TEST_DIR/external" "$DST"
  printf '%s' original > "$SRC/value"
  printf '%s' first > "$TEST_DIR/external/first"
  printf '%s' second > "$TEST_DIR/external/second"
  printf '%s' existing > "$DST/value"
  ln -sTnfr -- "$TEST_DIR/external/first" "$TEST_DIR/external/latest"
  ln -sTnfr -- "$SRC/value" "$SRC/nested/internal"
  ln -sTnf -- "$SRC/value" "$SRC/absolute-internal"
  ln -sTnf -- nested/internal "$SRC/chain"
  ln -sTnf -- ../../external/latest "$SRC/nested/external"
  ln -sTnf -- "$TEST_DIR/external/latest" "$SRC/absolute"
  ln -sTnfr -- "$TEST_DIR/missing" "$SRC/dangling"
  ln -sTnfr -- "$SRC" "$TEST_DIR/source-link"

  STAGING="$("$PCP" "$TEST_DIR/source-link" "$DST")"
  [[ $STAGING == "$TEST_DIR/output/.dog" ]]
  [[ $(< "$DST/value") == existing ]]
  [[ $(< "$STAGING/value") == original ]]
  for LINK in nested/internal absolute-internal chain nested/external absolute dangling; do
    [[ -L $STAGING/$LINK ]]
    TARGET="$(readlink -- "$STAGING/$LINK")"
    if [[ $TARGET == /* ]]; then exit 1; fi
  done
  if "$PCP" "$SRC" "$DST" > "$TEST_DIR/output-path" 2> "$TEST_DIR/error"; then exit 1; fi
  [[ $(< "$STAGING/value") == original ]]

  mv -- "$DST" "$TEST_DIR/output/.old"
  mv --no-target-directory -- "$STAGING" "$DST"
  printf '%s' changed > "$SRC/value"
  ln -sTnfr -- "$TEST_DIR/external/second" "$TEST_DIR/external/latest"
  [[ $(< "$DST/value") == original ]]
  [[ $(< "$DST/nested/internal") == original ]]
  [[ $(< "$DST/absolute-internal") == original ]]
  TARGET="$(readlink -- "$DST/chain")"
  [[ $TARGET == nested/internal ]]
  [[ $(< "$DST/chain") == original ]]
  [[ $(< "$DST/nested/external") == second ]]
  [[ $(< "$DST/absolute") == second ]]
  if [[ -e $DST/dangling ]]; then exit 1; fi
  printf '%s' arrived > "$TEST_DIR/missing"
  [[ $(< "$DST/dangling") == arrived ]]
  mv -- "$TEST_DIR/output" "$TEST_DIR/relocated"
  DST="$TEST_DIR/relocated/dog"
  [[ $(< "$DST/nested/internal") == original ]]
  [[ $(< "$DST/absolute-internal") == original ]]
  [[ $(< "$DST/nested/external") == second ]]
  ;;
publication)
  mkdir -p -- "$TEST_DIR/bin" "$TEST_DIR/old/data/launch" "$TEST_DIR/new/data/launch"
  for REVISION in old new; do
    printf '#!/usr/bin/env bash\nprintf "%s\\n"\n' "$REVISION" > "$TEST_DIR/$REVISION/run.sh"
    chmod +x -- "$TEST_DIR/$REVISION/run.sh"
    ln -sTnf -- "/$REVISION" "$TEST_DIR/$REVISION/data/launch/walk"
  done
  ln -sTnfr -- "$TEST_DIR/old" "$JOBS/dog"
  cat > "$TEST_DIR/bin/control" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
case "${0##*/}" in
s6-svok)
  if [[ $1 == */instances/* ]]; then
    exit "${TEST_SUPERVISOR_STATUS:-0}"
  fi
  ;;
s6-svwait)
  ln -sTnfr -- "$TEST_ROOT/new" "$TEST_ROOT/jobs/dog"
  ;;
s6-instance-create)
  cp --archive -- "${@: -2:1}/template" "${@: -2:1}/instances/${@: -1}"
  ln -sTnfr -- "${@: -2:1}/instances/${@: -1}" "${@: -2:1}/instance/${@: -1}"
  ;;
s6-instance-delete)
  if [[ ${TEST_DELETE_STATUS:-0} != 0 ]]; then
    exit "$TEST_DELETE_STATUS"
  fi
  rm -f -- "${@: -2:1}/instance/${@: -1}"
  rm -fr -- "${@: -2:1}/instances/${@: -1}"
  ;;
s6-svstat)
  printf '%s\n' "${TEST_SERVICE_STATUS:-false false}"
  ;;
s6-instance-control)
  if [[ $1 == -d ]]; then
    printf 'stop\n' >> "$TEST_ROOT/stops"
  fi
  ;;
esac
BASH
  chmod +x -- "$TEST_DIR/bin/control"
  for COMMAND in s6-svok s6-svwait s6-svc s6-instance-control s6-instance-create s6-instance-delete s6-svstat; do
    ln -sTnfr -- "$TEST_DIR/bin/control" "$TEST_DIR/bin/$COMMAND"
  done
  RECONCILE=(env "PATH=$TEST_DIR/bin:$PATH" "TEST_ROOT=$TEST_DIR" RECUR=job "${QUINE[@]}" dog)
  "${RECONCILE[@]}"
  SERVICE="$STATE/dog/instances/walk"
  diff --unified -- "$TEST_DIR/old/run.sh" "$SERVICE/data/.run"
  TARGET="$(readlink -- "$SERVICE/data/launch")"
  [[ $TARGET == /old ]]
  [[ -L $TEST_DIR/new/data/launch/walk ]]
  if [[ -L $TEST_DIR/old/data/launch/walk ]]; then exit 1; fi

  touch -- "$STATE/dog/data/.exited/walk"
  if TEST_DELETE_STATUS=111 "${RECONCILE[@]}"; then exit 1; fi
  [[ -d $SERVICE ]]
  [[ -f $STATE/dog/data/.exited/walk ]]
  [[ -L $TEST_DIR/new/data/launch/walk ]]
  "${RECONCILE[@]}"
  diff --unified -- "$TEST_DIR/new/run.sh" "$SERVICE/data/.run"
  TARGET="$(readlink -- "$SERVICE/data/launch")"
  [[ $TARGET == /new ]]
  if [[ -f $STATE/dog/data/.exited/walk ]]; then exit 1; fi

  printf '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
  TEST_SERVICE_STATUS='true true' "${RECONCILE[@]}"
  [[ -d $SERVICE ]]
  TEST_SERVICE_STATUS='true false' "${RECONCILE[@]}"
  [[ -d $SERVICE ]]
  [[ $(< "$TEST_DIR/stops") == stop ]]
  "${RECONCILE[@]}"
  if [[ -d $SERVICE ]]; then exit 1; fi

  mkdir -p -- "$TEST_DIR/new/env"
  printf '%s' 0 > "$TEST_DIR/new/env/S9_ON_UNIT_INACTIVE_SEC"
  ln -sTnf -- /new "$TEST_DIR/new/data/launch/walk"
  "${RECONCILE[@]}"
  touch -- "$SERVICE/stale"
  TEST_SUPERVISOR_STATUS=1 "${RECONCILE[@]}"
  [[ -d $SERVICE ]]
  if [[ -e $SERVICE/stale ]]; then exit 1; fi
  [[ -L $TEST_DIR/new/data/launch/walk ]]
  diff --unified -- "$TEST_DIR/new/run.sh" "$SERVICE/data/.run"

  touch -- "$STATE/dog/data/.exited/finished"
  "${RECONCILE[@]}"
  if [[ -e $STATE/dog/data/.exited/finished ]]; then exit 1; fi
  [[ -d $SERVICE ]]

  printf '%s' payload > "$TEST_DIR/new/data/payload"
  ln -sTnfr -- "$TEST_DIR/new/data/payload" "$TEST_DIR/new/data/launch/mail"
  printf '%s' -1 > "$TEST_DIR/new/env/S9_ON_UNIT_INACTIVE_SEC"
  "${RECONCILE[@]}"
  [[ $(< "$STATE/dog/instances/mail/data/launch") == payload ]]
  if [[ -L $TEST_DIR/new/data/launch/mail ]]; then exit 1; fi
  ;;
templates)
  JOB="$JOBS/dog"
  mkdir -p -- "$JOB/env" "$JOB/data/launch"
  cat > "$JOB/run.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s:%s:%s\n' "$1" "$PAYLOAD" "$(< "${0%/*}/value")"
BASH
  chmod +x -- "$JOB/run.sh"
  printf '%s' first > "$JOB/env/PAYLOAD"
  printf '%s' original > "$JOB/data/value"
  ln -sTnfr -- /dev/null "$JOB/data/launch/walk"
  ln -sTnfr -- "$JOB" "$JOBS/lil"
  for NAME in dog lil; do
    RECUR=seed "${QUINE[@]}" "$NAME" walk
    SERVICE="$STATE/$NAME/instances/walk"
    diff --unified -- "$JOB/run.sh" "$SERVICE/data/.run"
    diff --unified -- "$JOB/env/PAYLOAD" "$SERVICE/env/PAYLOAD"
    [[ $SERVICE/run -ef $SERVICE/data/lifecycle.sh ]]
    if [[ -e $SERVICE/data/launch ]] || [[ -L $SERVICE/data/launch ]]; then exit 1; fi
    if [[ -L $SERVICE/data/.run ]]; then exit 1; fi
    ACTUAL="$(s6-envdir -- "$SERVICE/env" "$SERVICE/data/.run" walk)"
    [[ $ACTUAL == walk:first:original ]]
  done
  RECUR=seed "${QUINE[@]}" dog walk
  diff --unified -- "$STATE/dog/template/.sum" "$STATE/dog/instances/walk/.sum"
  rm -- "$JOB/env/PAYLOAD" "$JOB/data/value"
  RECUR=seed "${QUINE[@]}" dog walk
  if [[ -e $STATE/dog/template/env/PAYLOAD ]] || [[ -e $STATE/dog/template/data/value ]]; then exit 1; fi
  SERVICE="$STATE/dog/instances/walk"
  ACTUAL="$(s6-envdir -- "$SERVICE/env" "$SERVICE/data/.run" walk)"
  [[ $ACTUAL == walk:first:original ]]
  ;;

queues)
  STEP="$TEST_DIR/queue-step"
  JOB="$JOBS/queue-dog"
  LAUNCH="$JOB/data/launch"
  MANAGER="$STATE/queue-dog"
  mkdir -p -- "$STEP/data/launch" "$TEST_DIR/bin"
  cat > "$STEP/run.sh" << 'BASH'
#!/usr/bin/env bash
exit 0
BASH
  chmod +x -- "$STEP/run.sh"
  ln -sTnfr -- "$STEP" "$JOB"
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
    ln -sTnfr -- "$TEST_DIR/bin/noop" "$TEST_DIR/bin/$COMMAND"
  done
  RECONCILE=(env "PATH=$TEST_DIR/bin:$PATH" RECUR=job "${QUINE[@]}")
  ln -sTnfr -- /missing/inbox "$LAUNCH/run"
  ln -sTnfr -- /dev/null "$LAUNCH/.pending"
  "${RECONCILE[@]}" queue-dog
  [[ -d $MANAGER/instances/run ]]
  [[ -L $MANAGER/instances/run/data/launch ]]
  if [[ -L $LAUNCH/run ]] || [[ -d $MANAGER/instances/.pending ]]; then
    exit 1
  fi
  [[ -L $LAUNCH/.pending ]]

  ln -sTnfr -- /dev/null "$LAUNCH/rejected"
  if "${RECONCILE[@]}" queue-dog; then
    exit 1
  fi
  [[ -L $LAUNCH/rejected ]]
  [[ -L $LAUNCH/rejected ]]
  if [[ -L $LAUNCH/run ]]; then
    exit 1
  fi

  ln -sTnfr -- /dev/null "$LAUNCH/run"
  if env -C "$MANAGER/instances/run" -- ./finish 0 0 run > "$TEST_DIR/finish.log"; then
    exit 1
  else
    [[ $? == 125 ]]
  fi
  [[ -L $LAUNCH/run ]]
  [[ -f $MANAGER/data/.exited/run ]]
  if [[ -L $MANAGER/instances/run/data/launch ]]; then
    exit 1
  fi

  mkdir -- "$STEP/env"
  printf '%s' 0 > "$STEP/env/S9_ON_UNIT_INACTIVE_SEC"
  rm -- "$LAUNCH/rejected"
  ln -sTnfr -- "$STEP" "$JOBS/daemon-dog"
  "${RECONCILE[@]}" daemon-dog
  [[ $(< "$STATE/daemon-dog/instances/run/env/S9_ON_UNIT_INACTIVE_SEC") == 0 ]]
  [[ -L $LAUNCH/run ]]
  SERVICE="$STATE/daemon-dog/instances/run"
  "${RECONCILE[@]}" daemon-dog
  if [[ -f $SERVICE/down ]]; then
    exit 1
  fi
  printf '%s' changed > "$STEP/env/PAYLOAD"
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
  mkdir -p -- "$SERVICE" "$STATE/dog/data/.exited" "$TEST_DIR/bin"
  rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
  printf '%s' "$SERVICE" > "$SERVICE/env/S9_WORKING_DIRECTORY"
  printf '%s' 2 > "$SERVICE/env/S9_RESTART_SEC"
  cat > "$SERVICE/data/.run" << 'BASH'
#!/usr/bin/env bash
printf '%s' "$1"
BASH
  cat > "$TEST_DIR/bin/sleep" << 'BASH'
#!/usr/bin/env bash
printf '%s' "${@: -1}" > ./delay
BASH
  chmod +x -- "$SERVICE/data/.run" "$TEST_DIR/bin/sleep"
  TEST_BIN="$(realpath -- "$TEST_DIR/bin")"
  ln -sTnfr -- /dev/null "$SERVICE/data/launch"
  trap 'printf "policy:%s interval=%s cap=%s status=%s delay=%s exit=%s attempts=%s: %s\n" "$LINENO" "$INTERVAL" "$CAP" "$STATUS" "$DELAY" "$EXPECTED_EXIT" "$EXPECTED_ATTEMPTS" "$BASH_COMMAND" >&2' ERR
  while read -r INTERVAL CAP STATUS DELAY EXPECTED_EXIT EXPECTED_ATTEMPTS; do
    printf '%s' "$INTERVAL" > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
    printf '%s' "${CAP#-}" > "$SERVICE/env/S9_RESTART_MAX_DELAY_SEC"
    rm -f -- "$SERVICE/delay"
    PATH="$TEST_BIN:$PATH" env -C "$SERVICE" -- ./run walk > "$TEST_DIR/output"
    if [[ -s $TEST_DIR/output ]]; then
      exit 1
    fi
    grep --quiet --fixed-strings 'dog@walk walk' "$TEST_DIR/live/dog@walk/log"
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
  [[ -f $STATE/dog/data/.exited/walk ]]
  if [[ -L $SERVICE/data/launch ]]; then
    exit 1
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
