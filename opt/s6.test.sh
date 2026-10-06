#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if (($# == 0)); then
  printf -- '%s\n' ctl watchdog snapshots p-cp publication templates queues policy logger finish-timeout runtime lifecycle dataflow contention joins scheduling | shuf | xargs --max-procs=0 --max-args=1 -- "$0"
  exit
fi
trap 'printf "%s [%s]:%s: %s\n" "$0" "$1" "$LINENO" "$BASH_COMMAND" >&2' ERR

ROOT="${0%.test.sh}"
S9_GRAPH_TIMEOUT="$(< "$ROOT/base/env/S9_GRAPH_TIMEOUT")"
export -- S9_GRAPH_TIMEOUT
mkdir -p -- "$ROOT/../../var/tmp"
TEST_DIR="$(mktemp -d -- "$ROOT/../../var/tmp/s6-test.XXXXXX")"
TEST_DIR="$(realpath -- "$TEST_DIR")"
STATE="$TEST_DIR/services"
JOBS="$TEST_DIR/jobs"
QUINE=(env -C "$STATE" -- "$JOBS/quine/run.sh")
trap 'rm -fr -- "$TEST_DIR"' EXIT
mkdir -- "$STATE"
cp --archive -- "$ROOT/." "$TEST_DIR/"

case "$1" in
scheduling)
  shopt -u failglob dotglob
  TOPOLOGY="$TEST_DIR/base/data/topology.sh"
  for JOB in dog slow report sibling; do
    mkdir -p -- "$JOBS/$JOB" "$STATE/$JOB/template/data/"{.s9,wants}
    ln -sTnf -- "$JOBS/$JOB" "$STATE/$JOB/template/data/.s9/source"
    printf -- '%s' "$JOB" > "$STATE/$JOB/template/data/.s9/defs.sum"
  done
  for JOB in report sibling; do
    ln -sTnfr -- "$JOBS/dog" "$STATE/$JOB/template/data/wants/dog"
  done
  for JOB in dog slow; do
    RECORD="$TEST_DIR/dead/$JOB/seed/20261005T000000.000000000"
    mkdir -p -- "$RECORD/outputs/row/.s9"
    printf -- '%s' "$JOB" > "$RECORD/outputs/row/value"
    cp -- "$STATE/$JOB/template/data/.s9/defs.sum" "$RECORD/outputs/row/.s9/defs.sum"
    ln -sTnfr -- "$RECORD" "${RECORD%/*}/latest-succ"
  done
  mkdir -- "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/ln" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="${0%/bin/ln}"
DST="${!#}"
case "$DST" in
"$ROOT/graph/".projection.*/dog/records/seed)
  printf -- '%s\n' dog >> "$ROOT/evaluations"
  if [[ ${FAIL_DOG:-} == 1 ]]; then exit 67; fi
  ;;
"$ROOT/graph/".projection.*/slow/records/seed)
  if [[ ${BARRIER:-} == 1 ]]; then
    timeout 10 bash -c 'shopt -s nullglob; LAUNCH="$1"; while :; do REQUESTS=("$LAUNCH"/*); if ((${#REQUESTS[@]})); then exit; fi; sleep 0.01; done' -- "$ROOT/services/report/data/.s9/launch"
  fi
  printf -- '%s\n' slow >> "$ROOT/evaluations"
  ;;
esac
exec -- "$REAL_LN" "$@"
BASH
  chmod +x -- "$TEST_DIR/bin/ln"
  REAL_LN="$(command -v ln)"
  export -- REAL_LN
  BARRIER=1 PATH="$TEST_DIR/bin:$PATH" timeout 20 "$TOPOLOGY" compile "$TEST_DIR" "$JOBS" > "$TEST_DIR/output" 2>&1
  for JOB in dog slow; do
    COUNT="$(grep --count "^$JOB$" "$TEST_DIR/evaluations")"
    [[ $COUNT == 1 ]]
  done
  for JOB in report sibling; do
    REQUESTS=("$STATE/$JOB/data/.s9/launch/"*)
    ((${#REQUESTS[@]} == 1))
    rm -- "${REQUESTS[@]}"
  done
  STATUS=0
  FAIL_DOG=1 PATH="$TEST_DIR/bin:$PATH" timeout 20 "$TOPOLOGY" projection "$TEST_DIR" > "$TEST_DIR/output" 2>&1 || STATUS=$?
  [[ $STATUS == 123 ]]
  for JOB in dog slow; do
    COUNT="$(grep --count "^$JOB$" "$TEST_DIR/evaluations")"
    [[ $COUNT == 2 ]]
  done
  REQUESTS=("$STATE/report/data/.s9/launch/"* "$STATE/sibling/data/.s9/launch/"*)
  ((${#REQUESTS[@]} == 0))
  ;;
joins)
  shopt -u failglob dotglob
  TOPOLOGY="$TEST_DIR/base/data/topology.sh"
  for JOB in dogs rules settings vacant matched mixed product missing empty single; do
    mkdir -p -- "$JOBS/$JOB/data/wants" "$STATE/$JOB/template/data/"{.s9,wants}
    ln -sTnf -- "$JOBS/$JOB" "$STATE/$JOB/template/data/.s9/source"
    printf -- '%s' "$JOB" > "$STATE/$JOB/template/data/.s9/defs.sum"
  done
  while read -r CONSUMER PRODUCER SIGIL; do
    for WANTS in "$JOBS/$CONSUMER/data/wants" "$STATE/$CONSUMER/template/data/wants"; do
      ln -sTnfr -- "$JOBS/$PRODUCER" "$WANTS/${SIGIL#-}$PRODUCER"
    done
  done << 'EOF'
matched dogs =
matched rules =
mixed dogs =
mixed rules =
mixed settings -
product dogs -
product rules -
missing dogs =
missing absent =
empty dogs =
empty vacant =
single dogs =
EOF
  cat > "$JOBS/matched/run.sh" << 'BASH'
#!/usr/bin/env bash
exit 0
BASH
  chmod +x -- "$JOBS/matched/run.sh"
  mkdir -- "$STATE/matched/instances" "$STATE/matched/instance"
  RECUR=seed "${QUINE[@]}" matched -
  [[ -L $STATE/matched/template/data/wants/=dogs ]]
  while IFS='|' read -r PRODUCER INSTANCE KEY VALUE; do
    RECORD="$TEST_DIR/dead/$PRODUCER/$INSTANCE/20261005T000000.000000000"
    mkdir -p -- "$RECORD/outputs/$KEY/.s9"
    printf -- '%s' "$VALUE" > "$RECORD/outputs/$KEY/value"
    cp -- "$STATE/$PRODUCER/template/data/.s9/defs.sum" "$RECORD/outputs/$KEY/.s9/defs.sum"
    printf -- '%s' 0 | tee "$RECORD/exit_status" > "$RECORD/signal"
    ln -sTnfr -- "$RECORD" "${RECORD%/*}/latest-succ"
  done << 'EOF'
dogs|one|shared|dog-one
dogs|one|left only|left
dogs|one|key[*]|literal-dog
dogs|one|brace{}key|brace-dog
dogs|two|shared|dog-two
dogs|three|shared|dog-one
rules|one|shared|rules
rules|one|right only|right
rules|one|key[*]|literal-rules
rules|one|brace{}key|brace-rules
settings|one|x|x
settings|one|y|y
EOF
  mkdir -- "$TEST_DIR/bin" "$TEST_DIR/parallel"
  cat > "$TEST_DIR/bin/tar" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="${0%/bin/tar}"
JOB="${PWD##*/}"
case "$JOB" in
matched | mixed | product | single)
  touch -- "$ROOT/parallel/$JOB"
  timeout 10 bash -c 'until [[ -f $1/matched ]] && [[ -f $1/mixed ]] && [[ -f $1/product ]] && [[ -f $1/single ]]; do sleep 0.01; done' -- "$ROOT/parallel"
  ;;
esac
if [[ $JOB == matched ]]; then
  for ARG in "$@"; do
    if [[ $ARG == --directory=* ]]; then
      touch -- "$ROOT/parallel/row-${ARG##*/}"
    fi
  done
  timeout 10 bash -c 'until [[ -f $1/row-shared ]] && [[ -f $1/row-key\[\*\] ]]; do sleep 0.01; done' -- "$ROOT/parallel"
fi
if [[ $JOB == "${FAIL_JOB:-}" ]]; then exit 67; fi
exec -- "$REAL_TAR" "$@"
BASH
  chmod +x -- "$TEST_DIR/bin/tar"
  REAL_TAR="$(command -v tar)"
  export -- REAL_TAR
  PATH="$TEST_DIR/bin:$PATH" "$TOPOLOGY" compile "$TEST_DIR" "$JOBS" > "$TEST_DIR/compile.log" 2>&1
  while read -r JOB EXPECTED; do
    REQUESTS=("$STATE/$JOB/data/.s9/launch/"*)
    if [[ ${#REQUESTS[@]} != "$EXPECTED" ]]; then
      printf -- 'join: job=%s expected=%s actual=%s\n' "$JOB" "$EXPECTED" "${#REQUESTS[@]}" >&2
      exit 1
    fi
  done << 'EOF'
matched 4
mixed 8
product 20
missing 0
empty 0
single 5
EOF
  for JOB in matched mixed; do
    for REQUEST in "$STATE/$JOB/data/.s9/launch/"*; do
      DOG="$(realpath -- "$REQUEST/dogs")"
      RULE="$(realpath -- "$REQUEST/rules")"
      [[ ${DOG##*/} == "${RULE##*/}" ]]
      [[ ${DOG##*/} == shared ]] || [[ ${DOG##*/} == 'key[*]' ]] || [[ ${DOG##*/} == 'brace{}key' ]]
      if [[ -e $REQUEST/=dogs ]] || [[ -e $REQUEST/=rules ]]; then exit 1; fi
      [[ $REQUEST -ef $TEST_DIR/graph/inputs/$JOB/${REQUEST##*/} ]]
    done
  done
  [[ -L $TEST_DIR/graph/topology/wants/matched/=dogs ]]
  if [[ -e $TEST_DIR/graph/topology/wanted-by ]]; then exit 1; fi
  REQUESTS=("$STATE/matched/data/.s9/launch/"*)
  "$TEST_DIR/base/data/dataflow.sh" prepare "$TEST_DIR" matched "${REQUESTS[0]##*/}" "${REQUESTS[0]}"
  [[ -d $TEST_DIR/live/matched/${REQUESTS[0]##*/}/inputs/dogs ]]
  if [[ -e $TEST_DIR/graph/cartesian-inputs ]]; then exit 1; fi
  printf -- '%s\n' "${REQUESTS[@]}" > "$TEST_DIR/before"
  "$TOPOLOGY" projection "$TEST_DIR"
  REQUESTS=("$STATE/matched/data/.s9/launch/"*)
  printf -- '%s\n' "${REQUESTS[@]}" > "$TEST_DIR/after"
  diff --unified -- "$TEST_DIR/before" "$TEST_DIR/after"
  STATUS=0
  FAIL_JOB=product PATH="$TEST_DIR/bin:$PATH" "$TOPOLOGY" projection "$TEST_DIR" > "$TEST_DIR/failure.log" 2>&1 || STATUS=$?
  ((STATUS != 0))
  PASSES=("$TEST_DIR/graph/".projection.*)
  ((${#PASSES[@]} == 0))
  ;;
contention)
  FLOW="$TEST_DIR/base/data/dataflow.sh"
  TOPOLOGY="$TEST_DIR/base/data/topology.sh"
  mkdir -- "$TEST_DIR/input"
  for JOB in dog report; do
    mkdir -p -- "$JOBS/$JOB" "$STATE/$JOB/template/data/.s9"
    ln -sTnf -- "$JOBS/$JOB" "$STATE/$JOB/template/data/.s9/source"
    printf -- '%s' "$JOB" > "$STATE/$JOB/template/data/.s9/defs.sum"
  done
  mkdir -p -- "$STATE/report/template/data/wants"
  ln -sTnfr -- "$JOBS/dog" "$STATE/report/template/data/wants/dog"
  "$TOPOLOGY" compile "$TEST_DIR" "$JOBS"
  for INSTANCE in walk trot; do
    SERVICE="$STATE/dog/instances/$INSTANCE"
    mkdir -p -- "$SERVICE/data/.s9" "$SERVICE/env"
    printf -- '%s' dog > "$SERVICE/data/.s9/defs.sum"
    printf -- '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
    "$FLOW" prepare "$TEST_DIR" dog "$INSTANCE" "$TEST_DIR/input"
    mkdir -- "$TEST_DIR/live/dog/$INSTANCE/outputs/row"
    printf -- '%s' "$INSTANCE" > "$TEST_DIR/live/dog/$INSTANCE/outputs/row/value"
  done
  LIVE="$TEST_DIR/live/dog/walk"
  RECORD="$TEST_DIR/dead/dog/walk/20260101T000000.000000000"
  mkdir -p -- "$LIVE/.s9"
  printf -- '%s' 0 | tee "$LIVE/exit_status" > "$LIVE/signal"
  printf -- '%s' "$RECORD" > "$LIVE/.s9/record"
  s6-setlock -- "$TEST_DIR/graph/.lock" s6-setlock -- "$STATE/.reconcile.lock" s6-setlock -- "$TEST_DIR/dead/dog/walk/.lock" timeout 10 bash -s -- "$TEST_DIR" << 'BASH' &
set -eu
touch -- "$1/locked"
while ! [[ -f $1/release ]]; do sleep 0.02; done
BASH
  HOLDER=$!
  trap 'STATUS=$?; touch -- "$TEST_DIR/release"; wait "$HOLDER"; rm -fr -- "$TEST_DIR"; exit "$STATUS"' EXIT
  timeout 3 bash -s -- "$TEST_DIR" << 'BASH'
until [[ -f $1/locked ]]; do sleep 0.02; done
BASH
  S9_GRAPH_TIMEOUT=1 "$FLOW" deliver "$TEST_DIR" dog trot 0 0
  [[ $(< "$TEST_DIR/dead/dog/trot/latest-succ/outputs/row/value") == trot ]]
  if [[ -d $STATE/report/data/.s9/launch ]]; then exit 1; fi
  "$FLOW" deliver "$TEST_DIR" absent stale
  if [[ -e $TEST_DIR/dead/absent ]]; then exit 1; fi
  TARGET="$(readlink -- "$TEST_DIR/graph/topology")"
  ACTUAL=0
  S9_GRAPH_TIMEOUT=1 "$TOPOLOGY" compile "$TEST_DIR" "$JOBS" > "$TEST_DIR/compile.log" 2>&1 || ACTUAL=$?
  [[ $ACTUAL == 1 ]]
  grep --quiet --fixed-strings 'timed out' "$TEST_DIR/compile.log"
  CURRENT="$(readlink -- "$TEST_DIR/graph/topology")"
  [[ $CURRENT == "$TARGET" ]]
  ACTUAL=0
  S9_GRAPH_TIMEOUT=1 "$FLOW" deliver "$TEST_DIR" dog walk > "$TEST_DIR/recovery.log" 2>&1 || ACTUAL=$?
  [[ $ACTUAL == 1 ]]
  grep --quiet --fixed-strings 'busy' "$TEST_DIR/recovery.log"
  ACTUAL=0
  S9_GRAPH_TIMEOUT=1 "$FLOW" prepare "$TEST_DIR" dog walk "$TEST_DIR/input" > "$TEST_DIR/prepare.log" 2>&1 || ACTUAL=$?
  [[ $ACTUAL == 1 ]]
  grep --quiet --fixed-strings 'timed out' "$TEST_DIR/prepare.log"
  [[ -f $LIVE/.s9/record ]]
  if [[ -d $RECORD ]]; then exit 1; fi
  touch -- "$TEST_DIR/release"
  wait "$HOLDER"
  trap 'rm -fr -- "$TEST_DIR"' EXIT
  "$FLOW" prepare "$TEST_DIR" dog walk "$TEST_DIR/input"
  [[ $(< "$RECORD/outputs/row/value") == walk ]]
  if [[ -e $LIVE/.s9/record ]] || [[ -d $LIVE/outputs/row ]]; then exit 1; fi
  "$TOPOLOGY" projection "$TEST_DIR"
  REQUESTS=("$STATE/report/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 2 ]]
  ;;
dataflow)
  shopt -u failglob dotglob
  FLOW="$TEST_DIR/base/data/dataflow.sh"
  TOPOLOGY="$TEST_DIR/base/data/topology.sh"
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
printf -- '%s' "${TEST_DEFINITION:-$1-v1}" > "$SERVICE/data/.s9/defs.sum"
printf -- '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
env -C "$SERVICE" -- ./finish "$3" "$4" "$2" > "$ROOT/finish.log"
"$ROOT/base/data/topology.sh" projection "$ROOT/runtime"
BASH
  chmod +x -- "$FINISH"
  for JOB in producer-1 producer-2 consumer sink bystander; do
    mkdir -p -- "$JOBS/$JOB/data/.s9/launch" "$SERVICES/$JOB/template/data/.s9" "$SERVICES/$JOB/instances"
    printf -- '%s' "$JOB-v1" > "$SERVICES/$JOB/template/data/.s9/defs.sum"
  done
  mv -- "$JOBS/producer-1" "$TEST_DIR/producer-snapshot"
  ln -sTnfr -- "$TEST_DIR/producer-snapshot" "$JOBS/producer-1"
  for JOB in producer-1 producer-2 consumer sink bystander; do
    TARGET="$(realpath -- "$JOBS/$JOB")"
    ln -sTnf -- "$TARGET" "$SERVICES/$JOB/template/data/.s9/source"
  done
  mkdir -p -- "$JOBS/consumer/data/wants" "$JOBS/sink/data/wants" "$JOBS/bystander/data/wants"
  ln -sTnfr -- "$JOBS/producer-1" "$JOBS/consumer/data/wants/first"
  ln -sTnfr -- "$JOBS/producer-2" "$JOBS/consumer/data/wants/second"
  ln -sTnfr -- "$JOBS/consumer" "$JOBS/sink/data/wants/result"
  ln -sTnfr -- "$JOBS/producer-2" "$JOBS/bystander/data/wants/other"
  for JOB in consumer sink bystander; do
    mkdir -p -- "$SERVICES/$JOB/template/data/wants"
    for WANT in "$JOBS"/"$JOB"/data/wants/*; do
      ln -sTnfr -- "$WANT" "$SERVICES/$JOB/template/data/wants/${WANT##*/}"
    done
  done
  for JOB in producer-1 producer-2; do
    HASH="$(printf '%s' "$JOB" | b3sum)"
    HASH="${HASH%% *}"
    ln -sTnfr -- "$INPUT" "$JOBS/$JOB/data/.s9/launch/$HASH"
    "$FLOW" prepare "$RUNTIME" "$JOB" "$HASH" "$INPUT"
    if [[ $JOB == producer-2 ]]; then
      mkdir -- "$TEST_DIR/$JOB-outputs"
      rmdir -- "$RUNTIME/live/$JOB/$HASH/outputs"
      ln -sTnfr -- "$TEST_DIR/$JOB-outputs" "$RUNTIME/live/$JOB/$HASH/outputs"
    fi
    mkdir -- "$RUNTIME/live/$JOB/$HASH/outputs/A" "$TEST_DIR/$JOB-row"
    ln -sTnfr -- "$TEST_DIR/$JOB-row" "$RUNTIME/live/$JOB/$HASH/outputs/B"
    for ROW in A B; do
      OUTPUT="$RUNTIME/live/$JOB/$HASH/outputs/$ROW"
      mkdir -- "$OUTPUT/nested"
      printf -- '%s' payload > "$OUTPUT/nested/value"
      printf -- '%s' hidden > "$OUTPUT/.hidden"
      ln -sTnfr -- "$OUTPUT/nested/value" "$OUTPUT/alias"
    done
    printf -- '%s' "$JOB" > "$RUNTIME/live/$JOB/$HASH/log"
    "$FINISH" "$JOB" "$HASH" 0 0
    rm -- "$JOBS/$JOB/data/.s9/launch/$HASH"
    RECORD="$(realpath -- "$RUNTIME/dead/$JOB/$HASH/latest-succ")"
    for ROW in A B; do
      [[ $(< "$RECORD/outputs/$ROW/.s9/defs.sum") == "$JOB-v1" ]]
    done
    if [[ -f $TEST_DIR/$JOB-row/.s9/defs.sum ]]; then exit 1; fi
    if [[ -f $TEST_DIR/$JOB-outputs/A/.s9/defs.sum ]]; then exit 1; fi
  done
  "$TOPOLOGY" compile "$RUNTIME" "$JOBS"
  BEFORE="$(readlink -- "$RUNTIME/graph/topology")"
  "$TOPOLOGY" compile "$RUNTIME" "$JOBS"
  AFTER="$(readlink -- "$RUNTIME/graph/topology")"
  [[ $AFTER == "$BEFORE" ]]
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 4 ]]
  if "$TOPOLOGY" combine "$RUNTIME" "$RUNTIME/graph/topology/wants/consumer" "$TEST_DIR/pass" '' producer-1 "$TEST_DIR/missing-row" producer-2 '' > "$TEST_DIR/output" 2>&1; then exit 1; fi
  for PRODUCER in producer-1 producer-2; do
    TARGET="$(readlink -- "$RUNTIME/graph/topology/wants/consumer/$PRODUCER")"
    [[ $TARGET == "../$PRODUCER" ]]
    [[ $RUNTIME/graph/topology/wants/consumer/$PRODUCER -ef $RUNTIME/graph/topology/wants/$PRODUCER ]]
  done
  REQUEST="${REQUESTS[0]}"
  for JOB in sink sink; do
    "$TOPOLOGY" visit "$RUNTIME" "$RUNTIME/graph/topology/wants/$JOB" "$TEST_DIR/visit"
  done
  for JOB in producer-1 producer-2 consumer sink; do
    [[ -f $TEST_DIR/visit/$JOB/visited ]]
  done
  HASH="${REQUEST##*/}"
  INPUTS="$RUNTIME/graph/inputs/consumer/$HASH"
  [[ $REQUEST -ef $INPUTS ]]
  STAGING="${INPUTS%/*}/.$HASH"
  rm -- "$REQUEST"
  mkdir -p -- "$RUNTIME/dead/consumer/$HASH/.unfinished"
  printf -- '%s' 0 > "$RUNTIME/dead/consumer/$HASH/.unfinished/exit_status"
  mv -- "$INPUTS" "$STAGING"
  printf -- '%s' incomplete > "$STAGING/.s9/defs.sum"
  rm -- "$STAGING/producer-1"
  "$TOPOLOGY" projection "$RUNTIME"
  [[ $REQUEST -ef $INPUTS ]]
  [[ $(< "$INPUTS/.s9/defs.sum") == consumer-v1 ]]
  [[ -d $INPUTS/producer-1 ]]
  if [[ -d $STAGING ]]; then exit 1; fi
  for REQUEST in "${REQUESTS[@]}"; do
    HASH="${REQUEST##*/}"
    [[ $(< "$REQUEST/.s9/defs.sum") == consumer-v1 ]]
    SERVICE="$SERVICES/consumer/instances/$HASH"
    mkdir -p -- "$SERVICE"
    rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
    cp -- "$SERVICES/consumer/template/data/.s9/defs.sum" "$SERVICE/data/.s9/defs.sum"
    cat > "$SERVICE/data/.run" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 5
test "$4" = 'extra argument'
test "$5" = ''
[[ $2 == /* ]] && [[ $3 == /* ]]
test -d "$2/producer-1"
test -d "$2/producer-2"
mkdir -p -- "$3/result/.s9"
ln -sTnfr -- "$0" "$3/result/.s9/defs.sum"
printf -- '%s' "$1" > "$3/result/value"
BASH
    chmod +x -- "$SERVICE/data/.run"
    TARGET="$(realpath -- "$REQUEST")"
    ln -sTnf -- "$TARGET" "$REQUEST"
    mv -- "$REQUEST" "$SERVICES/consumer/instances/$HASH/data/.s9/launch"
    "$FLOW" prepare "$RUNTIME" consumer "$HASH" "$SERVICES/consumer/instances/$HASH/data/.s9/launch"
    ln -sTnfr -- "$RUNTIME/live/consumer/$HASH/inputs/producer-1" "$RUNTIME/live/consumer/$HASH/inputs/shared"
    "$FLOW" prepare "$RUNTIME" consumer "$HASH" "$SERVICES/consumer/instances/$HASH/data/.s9/launch"
    [[ $RUNTIME/live/consumer/$HASH/inputs/shared -ef $RUNTIME/live/consumer/$HASH/inputs/producer-1 ]]
    TELEMETRY=("$RUNTIME/live/consumer/$HASH/telemetry/"*)
    [[ ${#TELEMETRY[@]} == 2 ]]
    for LINK in "${TELEMETRY[@]}"; do
      TARGET="$(readlink -- "$LINK")"
      [[ $TARGET == ../../../../dead/*/*/* ]]
      [[ -f $LINK/exit_status ]]
      ID="${LINK##*/}"
      ATTEMPT="${ID#*@}"
      [[ $LINK -ef $RUNTIME/dead/${ID%%@*}/${ATTEMPT%%.*}/${ATTEMPT#*.} ]]
    done
    if [[ -L $RUNTIME/live/consumer/$HASH/inputs ]]; then exit 1; fi
    [[ -d $RUNTIME/live/consumer/$HASH/inputs/producer-1 ]]
    TARGET="$(readlink -- "$RUNTIME/live/consumer/$HASH/inputs/producer-1")"
    [[ $TARGET == ../telemetry/producer-1@*/outputs/* ]]
    if [[ -e $RUNTIME/live/consumer/$HASH/inputs/first ]]; then exit 1; fi
    "$TOPOLOGY" projection "$RUNTIME"
    if [[ -L $REQUEST ]]; then exit 1; fi
    S9_WORKING_DIRECTORY="$TEST_DIR" env -C "$SERVICE" -- ./run "$HASH" 'extra argument' '' > "$TEST_DIR/output"
    rm -- "$SERVICE/data/.s9/pgid"
    printf -- '%s' consumer-newer > "$SERVICES/consumer/template/data/.s9/defs.sum"
    BYSTANDER_REQUESTS=("$SERVICES/bystander/data/.s9/launch/"*)
    [[ ${#BYSTANDER_REQUESTS[@]} == 2 ]]
    rm -- "${BYSTANDER_REQUESTS[@]}"
    STATUS=0
    env -C "$SERVICE" -- ./finish 0 0 "$HASH" > "$TEST_DIR/output" || STATUS=$?
    [[ $STATUS == 125 ]]
    "$TOPOLOGY" projection "$RUNTIME"
    printf -- '%s' consumer-v1 > "$SERVICES/consumer/template/data/.s9/defs.sum"
    BYSTANDER_REQUESTS=("$SERVICES/bystander/data/.s9/launch/"*)
    [[ ${#BYSTANDER_REQUESTS[@]} == 2 ]]
    SINK_REQUESTS=("$SERVICES/sink/data/.s9/launch/"*)
    ((${#SINK_REQUESTS[@]} > 0))
    RECORD="$(realpath -- "$RUNTIME/dead/consumer/$HASH/latest-succ")"
    [[ ${RECORD%/*} == "$RUNTIME/dead/consumer/$HASH" ]]
    TARGET="$(readlink -- "$RUNTIME/dead/consumer/$HASH/latest-succ")"
    [[ $TARGET == "${RECORD##*/}" ]]
    [[ $(< "$RECORD/outputs/result/value") == "$HASH" ]]
    [[ $(< "$RECORD/outputs/result/.s9/defs.sum") == consumer-v1 ]]
    if [[ -L $RECORD/outputs/result/.s9/defs.sum ]]; then exit 1; fi
    [[ $(< "$RECORD/inputs/.s9/defs.sum") == consumer-v1 ]]
    if [[ -L $RECORD/inputs ]]; then exit 1; fi
    rm -fr -- "$RUNTIME/graph/inputs/consumer/$HASH"
    [[ -d $RECORD/inputs/producer-1 ]]
    [[ -d $RECORD/inputs/producer-2 ]]
    TARGET="$(readlink -- "$RECORD/inputs/producer-1")"
    [[ $TARGET == ../telemetry/producer-1@*/outputs/* ]]
    [[ -L $SERVICE/data/.s9/died ]]
    [[ $SERVICE/data/.s9/died -ef $RECORD ]]
    TARGET="$(readlink -- "$SERVICE/data/.s9/died")"
    [[ $TARGET == ../../../../../../dead/consumer/$HASH/* ]]
    rm -fr -- "$SERVICES/consumer/instances/$HASH"
  done
  REQUESTS=("$SERVICES/sink/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 4 ]]
  for REQUEST in "${REQUESTS[@]}"; do
    HASH="${REQUEST##*/}"
    "$FLOW" prepare "$RUNTIME" sink "$HASH" "$REQUEST"
    mkdir -- "$RUNTIME/live/sink/$HASH/outputs/partial"
    TELEMETRY=("$RUNTIME/live/sink/$HASH/telemetry/"*)
    [[ ${#TELEMETRY[@]} == 3 ]]
    "$FINISH" sink "$HASH" 67 0
    [[ $(< "$RUNTIME/fail/sink/$HASH/latest/outputs/partial/.s9/defs.sum") == sink-v1 ]]
    rm -- "$REQUEST"
  done
  printf -- '%s\0' projection projection projection | xargs --null --max-procs=0 -I '{}' -- "$TOPOLOGY" '{}' "$RUNTIME"
  REQUESTS=("$SERVICES/sink/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  HASH="$(printf '%s' producer-1 | b3sum)"
  HASH="${HASH%% *}"
  PREVIOUS="$(realpath -- "$RUNTIME/dead/producer-1/$HASH/latest-succ")"
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  rsync --archive -- "$PREVIOUS/outputs/" "$RUNTIME/live/producer-1/$HASH/outputs/"
  find "$RUNTIME/live/producer-1/$HASH/outputs" -type f -exec touch --date=20000101 -- {} +
  "$FINISH" producer-1 "$HASH" 0 0
  CURRENT="$(realpath -- "$RUNTIME/dead/producer-1/$HASH/latest-succ")"
  [[ $CURRENT != "$PREVIOUS" ]]
  [[ $(< "$CURRENT/outputs/A/.s9/defs.sum") == producer-1-v1 ]]
  "$TOPOLOGY" projection "$RUNTIME"
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"* "$SERVICES/sink/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  rsync --archive -- "$CURRENT/outputs/" "$RUNTIME/live/producer-1/$HASH/outputs/"
  TEST_DEFINITION=producer-1-v2 "$FINISH" producer-1 "$HASH" 0 0
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 4 ]]
  rm -- "${REQUESTS[@]}"
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  rsync --archive -- "$CURRENT/outputs/" "$RUNTIME/live/producer-1/$HASH/outputs/"
  "$FINISH" producer-1 "$HASH" 0 0
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  printf -- '%s' consumer-v2 > "$SERVICES/consumer/template/data/.s9/defs.sum"
  "$TOPOLOGY" compile "$RUNTIME" "$JOBS"
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 4 ]]
  rm -- "${REQUESTS[@]}"
  printf -- '%s' consumer-v1 > "$SERVICES/consumer/template/data/.s9/defs.sum"
  "$TOPOLOGY" compile "$RUNTIME" "$JOBS"
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  HASH="$(printf '%s' producer-1 | b3sum)"
  HASH="${HASH%% *}"
  PREVIOUS="$(realpath -- "$RUNTIME/dead/producer-1/$HASH/latest-succ")"
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  "$FINISH" producer-1 "$HASH" 67 0
  [[ $RUNTIME/dead/producer-1/$HASH/latest-succ -ef $PREVIOUS ]]
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  mkdir -- "$RUNTIME/live/producer-1/$HASH/outputs/A"
  printf -- '%s' changed > "$RUNTIME/live/producer-1/$HASH/outputs/A/value"
  "$FINISH" producer-1 "$HASH" 0 0
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 2 ]]
  for REQUEST in "${REQUESTS[@]}"; do
    [[ -d $REQUEST/producer-1 ]]
    [[ ${REQUEST##*/} != "${PREVIOUS##*/}" ]]
  done
  rm -- "${REQUESTS[@]}"
  printf -- '%s' consumer-v3 > "$SERVICES/consumer/template/data/.s9/defs.sum"
  "$TOPOLOGY" compile "$RUNTIME" "$JOBS"
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 2 ]]
  CURRENT="$(realpath -- "$RUNTIME/dead/producer-1/$HASH/latest-succ")"
  for REQUEST in "${REQUESTS[@]}"; do
    [[ $REQUEST/producer-1 -ef $CURRENT/outputs/A ]]
  done
  rm -- "${REQUESTS[@]}"
  printf -- '%s' sink-v2 > "$SERVICES/sink/template/data/.s9/defs.sum"
  "$TOPOLOGY" compile "$RUNTIME" "$JOBS"
  REQUESTS=("$SERVICES/sink/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  "$FLOW" prepare "$RUNTIME" producer-1 "$HASH" "$INPUT"
  "$FINISH" producer-1 "$HASH" 0 0
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  for REQUEST in "${REQUESTS[@]}"; do rm -- "$REQUEST"; done
  "$TOPOLOGY" projection "$RUNTIME"
  REQUESTS=("$SERVICES/consumer/data/.s9/launch/"*)
  [[ ${#REQUESTS[@]} == 0 ]]
  "$FLOW" prepare "$RUNTIME" recovery record "$INPUT"
  mkdir -- "$RUNTIME/live/recovery/record/outputs/row"
  "$FINISH" recovery record 0 0
  RECORD="$(realpath -- "$RUNTIME/dead/recovery/record/latest-succ")"
  rm -- "$RUNTIME/dead/recovery/record/latest-succ"
  mkdir -p -- "$RUNTIME/live/recovery/record/.s9"
  cp -- "$RECORD/"{exit_status,signal} "$RUNTIME/live/recovery/record/"
  printf -- '%s' "$RECORD" > "$RUNTIME/live/recovery/record/.s9/record"
  mkdir -p -- "$RUNTIME/live/incomplete/record/.s9"
  printf -- '%s' partial > "$RUNTIME/live/incomplete/record/.s9/record-next"
  "$TOPOLOGY" compile "$RUNTIME" "$JOBS"
  [[ $(< "$RUNTIME/live/incomplete/record/.s9/record-next") == partial ]]
  [[ -d $RUNTIME/dead/recovery/record/latest-succ/outputs/row ]]
  if [[ -d $RUNTIME/live/recovery/record ]]; then exit 1; fi
  "$FLOW" deliver "$RUNTIME" recovery record
  if [[ -d $RUNTIME/live/recovery/record ]]; then exit 1; fi
  if [[ -e $RUNTIME/graph/indices ]]; then exit 1; fi

  "$FLOW" prepare "$RUNTIME" archive-failure record "$INPUT"
  mkdir -- "$RUNTIME/live/archive-failure/record/outputs/row"
  printf -- '%s' retained > "$RUNTIME/live/archive-failure/record/outputs/row/value"
  mv -- "$RUNTIME/dead/archive-failure" "$RUNTIME/dead/archive-saved"
  printf -- '%s' blocked > "$RUNTIME/dead/archive-failure"
  if "$FINISH" archive-failure record 67 0; then exit 1; fi
  [[ -f $RUNTIME/live/archive-failure/record/.s9/record ]]
  [[ $(< "$RUNTIME/live/archive-failure/record/exit_status") == 67 ]]
  rm -- "$RUNTIME/dead/archive-failure"
  mv -- "$RUNTIME/dead/archive-saved" "$RUNTIME/dead/archive-failure"
  "$FLOW" deliver "$RUNTIME" archive-failure record
  [[ $(< "$RUNTIME/fail/archive-failure/record/latest/outputs/row/value") == retained ]]
  [[ $(< "$RUNTIME/fail/archive-failure/record/latest/exit_status") == 67 ]]
  if [[ -d $RUNTIME/live/archive-failure/record ]]; then exit 1; fi

  mkdir -- "$TEST_DIR/lock-bin"
  cat > "$TEST_DIR/lock-bin/s6-setlock" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${4:-} != "$TEST_RUNTIME/dead/recovery-race/record/.lock" ]]; then
  exec "$TEST_SETLOCK" "$@"
fi
LOCK_ARGS=("${@:1:4}")
shift 4
exec "$TEST_SETLOCK" "${LOCK_ARGS[@]}" bash "$TEST_RECOVER" "$@"
BASH
  cat > "$TEST_DIR/recover-first.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
RECUR=record "$TEST_FLOW" deliver "$TEST_RUNTIME" recovery-race record
exec "$@"
BASH
  chmod +x -- "$TEST_DIR/lock-bin/s6-setlock"
  "$FLOW" prepare "$RUNTIME" recovery-race record "$INPUT"
  mkdir -- "$RUNTIME/live/recovery-race/record/outputs/row"
  TEST_SETLOCK="$(command -v -- s6-setlock)"
  TEST_SETLOCK="$TEST_SETLOCK" TEST_RECOVER="$TEST_DIR/recover-first.sh" TEST_FLOW="$FLOW" TEST_RUNTIME="$RUNTIME" PATH="$TEST_DIR/lock-bin:$PATH" "$FINISH" recovery-race record 0 0
  RECORDS=("$RUNTIME/dead/recovery-race/record/"[0-9]*)
  [[ ${#RECORDS[@]} == 1 ]]
  [[ -d $RUNTIME/dead/recovery-race/record/latest-succ/outputs/row ]]
  if [[ -d $RUNTIME/live/recovery-race/record ]]; then exit 1; fi

  mkdir -p -- "$JOBS/recovery" "$SERVICES/recovery/template/data/.s9"
  printf -- '%s' recovery-v1 > "$SERVICES/recovery/template/data/.s9/defs.sum"
  ln -sTnf -- "$JOBS/recovery" "$SERVICES/recovery/template/data/.s9/source"
  for JOB in missing-only missing-partial healthy; do
    mkdir -p -- "$JOBS/$JOB" "$SERVICES/$JOB/template/data/wants" "$SERVICES/$JOB/template/data/.s9"
    printf -- '%s' "$JOB-v1" > "$SERVICES/$JOB/template/data/.s9/defs.sum"
    ln -sTnf -- "$JOBS/$JOB" "$SERVICES/$JOB/template/data/.s9/source"
    if [[ $JOB != healthy ]]; then
      ln -sTnfr -- "$TEST_DIR/absent/producer" "$SERVICES/$JOB/template/data/wants/missing"
    fi
    if [[ $JOB != missing-only ]]; then
      ln -sTnfr -- "$JOBS/recovery" "$SERVICES/$JOB/template/data/wants/recovery"
    fi
  done
  "$TOPOLOGY" compile "$RUNTIME" "$JOBS" > "$TEST_DIR/output" 2>&1
  grep --quiet 'Unknown dependency:' "$TEST_DIR/output"
  for JOB in missing-only missing-partial healthy; do
    REQUESTS=("$SERVICES/$JOB/data/.s9/launch/"*)
    [[ ${#REQUESTS[@]} == 1 ]]
    if [[ -e ${REQUESTS[0]}/missing ]] || [[ -L ${REQUESTS[0]}/missing ]]; then exit 1; fi
    if [[ $JOB != missing-only ]]; then
      [[ -d ${REQUESTS[0]}/recovery ]]
    fi
  done
  mkdir -p -- "$JOBS/producer-1/data/wants"
  ln -sTnfr -- "$JOBS/sink" "$JOBS/producer-1/data/wants/cycle"
  mkdir -p -- "$SERVICES/producer-1/template/data/wants"
  ln -sTnfr -- "$JOBS/sink" "$SERVICES/producer-1/template/data/wants/cycle"
  printf -- '%s' with-cycle > "$SERVICES/producer-1/template/data/.s9/defs.sum"
  if "$TOPOLOGY" compile "$RUNTIME" "$JOBS" > "$TEST_DIR/output" 2>&1; then exit 1; fi
  grep --quiet 'Dependency cycle' "$TEST_DIR/output"
  ;;
ctl)
  RUNTIME="$TEST_DIR/runtime"
  mkdir -p -- "$TEST_DIR/bin" "$RUNTIME/dead" "$RUNTIME/fail"
  printf -- '%s' retained > "$RUNTIME/dead/existing.log"
  printf -- '%s' retained > "$RUNTIME/fail/existing"
  cat > "$TEST_DIR/bin/ps" << 'BASH'
#!/usr/bin/env bash
printf -- 'parent start time\n'
BASH
  cat > "$TEST_DIR/bin/s6-svscan" << 'BASH'
#!/usr/bin/env bash
printf -- '%s\n' "${@: -1}"
printf -- 'inherited descriptor\n' >&67
BASH
  chmod +x -- "$TEST_DIR/bin/"{ps,s6-svscan}
  for _ in 1 2; do
    PATH="$TEST_DIR/bin:$PATH" "$TEST_DIR/ctl.sh" start "$RUNTIME" "$TEST_DIR" 67
    for DIR in services live dead fail; do
      [[ -d $RUNTIME/$DIR ]]
    done
    [[ -d $RUNTIME/services/quine/instances/- ]]
    [[ -d $RUNTIME/services/watchdog/instances/67 ]]
    [[ $(< "$RUNTIME/services/watchdog/data/.s9/launch/67") == 'parent start time' ]]
    [[ $(< "$RUNTIME/dead/existing.log") == retained ]]
    [[ $(< "$RUNTIME/fail/existing") == retained ]]
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
watchdog)
  mkdir -- "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/ps" << 'BASH'
#!/usr/bin/env bash
printf -- '%s\n' "$TEST_STARTED"
exit "$TEST_PS_STATUS"
BASH
  cat > "$TEST_DIR/bin/s6-svscanctl" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == -t ]]
realpath -- "${@: -1}" > "$TEST_STOP"
BASH
  chmod +x -- "$TEST_DIR/bin/"{ps,s6-svscanctl}
  RECUR=seed "${QUINE[@]}" watchdog 67
  mkdir -p -- "$STATE/watchdog/data/.s9/launch"
  printf -- '%s' 'parent start time' > "$STATE/watchdog/data/lstart"
  ln -sTnfr -- "$STATE/watchdog/data/lstart" "$STATE/watchdog/data/.s9/launch/67"
  while IFS='|' read -r STATUS STARTED EXPECTED; do
    rm -f -- "$TEST_DIR/stopped"
    TEST_PS_STATUS="$STATUS" TEST_STARTED="$STARTED" TEST_STOP="$TEST_DIR/stopped" PATH="$TEST_DIR/bin:$PATH" "$STATE/watchdog/instances/67/data/.run" 67
    case "$EXPECTED" in
    keep) if [[ -e $TEST_DIR/stopped ]]; then exit 1; fi ;;
    stop) [[ $(< "$TEST_DIR/stopped") == "$STATE" ]] ;;
    *)
      set -x
      exit 2
      ;;
    esac
  done << 'EOF'
0|parent start time|keep
0|different start time|stop
1||stop
EOF
  ;;
finish-timeout)
  SERVICE="$STATE/dog/instances/walk"
  mkdir -p -- "$SERVICE" "$TEST_DIR/bin"
  rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
  printf -- '%s' 7 > "$SERVICE/env/S9_GRAPH_TIMEOUT"
  REAL_TIMEOUT="$(command -v -- timeout)"
  cat > "$TEST_DIR/bin/timeout" << 'BASH'
#!/usr/bin/env bash
set -eu
[[ $1 == --signal=KILL ]]
[[ $2 == 14 ]]
shift -- 2
exec -- "$REAL_TIMEOUT" --signal=KILL 0.2 "$@"
BASH
  cat > "$TEST_DIR/stall" << 'BASH'
#!/usr/bin/env bash
set -eu
trap '' TERM
(
  sleep 1
  printf -- 'survived\n' > "$TEST_DIR/survived"
) &
wait
BASH
  chmod +x -- "$TEST_DIR/bin/timeout" "$TEST_DIR/stall"
  for STALLED in logger delivery; do
    case "$STALLED" in
    logger) ln -sTnfr -- "$TEST_DIR/stall" "$TEST_DIR/bin/s6-log" ;;
    delivery)
      rm -- "$TEST_DIR/bin/s6-log"
      cp -- "$TEST_DIR/stall" "$SERVICE/data/dataflow.sh"
      ;;
    *)
      set -x
      exit 2
      ;;
    esac
    ACTUAL=0
    {
      env -C "$SERVICE" -- "TEST_DIR=$TEST_DIR" "REAL_TIMEOUT=$REAL_TIMEOUT" "PATH=$TEST_DIR/bin:$PATH" ./finish 0 0 walk || ACTUAL=$?
    } > "$TEST_DIR/output" 2>&1
    [[ $ACTUAL == 137 ]]
    sleep 1
    if [[ -e $TEST_DIR/survived ]]; then
      exit 1
    fi
  done
  [[ $(< "$SERVICE/timeout-finish") == 15000 ]]
  ;;
logger)
  for INSTANCE in walk log; do
    SERVICE="$STATE/dog/instances/$INSTANCE"
    mkdir -p -- "$SERVICE"
    rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
    printf -- '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
    cat > "$SERVICE/data/.run" << 'BASH'
#!/usr/bin/env bash
printf -- 'ran\n' > "${0%/*}/ran"
printf -- 'command stdout\n'
printf -- 'command stderr\n' >&2
exit "${TEST_JOB_STATUS:-0}"
BASH
    chmod +x -- "$SERVICE/data/.run"
    for STATUS in 0 67; do
      ACTUAL=0
      TEST_JOB_STATUS="$STATUS" S9_WORKING_DIRECTORY="$TEST_DIR" env -C "$SERVICE" -- ./run "$INSTANCE" > "$TEST_DIR/output" || ACTUAL=$?
      [[ $ACTUAL == "$STATUS" ]]
      [[ -s $SERVICE/data/.s9/pgid ]]
      if [[ -s $TEST_DIR/output ]]; then
        exit 1
      fi
      rm -- "$SERVICE/data/.s9/pgid"
      env -C "$SERVICE" -- ./finish "$STATUS" 0 "$INSTANCE" | env -C "$SERVICE/log" -- ./run 3> "$TEST_DIR/ready" 67>&1 | s6-log -b -l 0 -- T 1 >> "$TEST_DIR/live/s6.log"
      diff --unified -- <(printf '\n') "$TEST_DIR/ready"
      grep --quiet --fixed-strings -- "dog@$INSTANCE --- exit_status=$STATUS signal=0 ---" "$TEST_DIR/live/s6.log"
    done
    if [[ -e $TEST_DIR/live/dog/$INSTANCE/log ]]; then
      exit 1
    fi
    ARCHIVES=("$TEST_DIR/dead/dog/$INSTANCE/"[0-9]*/log)
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
    DEAD=("$TEST_DIR/dead/dog/$INSTANCE/"[0-9]*)
    [[ ${#DEAD[@]} == 2 ]]
    [[ $TEST_DIR/dead/dog/$INSTANCE/latest-succ -ef ${DEAD[0]} ]]
    [[ $(< "${DEAD[0]}/exit_status") == 0 ]]
    [[ $(< "${DEAD[0]}/signal") == 0 ]]
    FAILED=("$TEST_DIR/fail/dog/$INSTANCE/"[0-9]*)
    [[ ${#FAILED[@]} == 1 ]]
    [[ -L ${FAILED[0]} ]]
    [[ ${FAILED[0]} -ef ${DEAD[1]} ]]
    [[ $TEST_DIR/fail/dog/$INSTANCE/latest -ef ${FAILED[0]} ]]
    TARGET="$(readlink -- "$TEST_DIR/fail/dog/$INSTANCE/latest")"
    [[ $TARGET == "${FAILED[0]##*/}" ]]
    TARGET="$(readlink -- "${FAILED[0]}")"
    [[ $TARGET == "../../../dead/dog/$INSTANCE/${DEAD[1]##*/}" ]]
    [[ $(< "${FAILED[0]}/exit_status") == 67 ]]
    [[ $(< "${FAILED[0]}/signal") == 0 ]]
  done
  if grep --quiet --fixed-strings 'command stdout' "$TEST_DIR/live/s6.log"; then
    exit 1
  fi
  env -C "$SERVICE" -- ./finish 256 15 "$INSTANCE" > "$TEST_DIR/finish.log"
  FAILED=("$TEST_DIR/fail/dog/$INSTANCE/"[0-9]*)
  [[ ${#FAILED[@]} == 2 ]]
  [[ $(< "${FAILED[1]}/exit_status") == 256 ]]
  [[ $(< "${FAILED[1]}/signal") == 15 ]]
  [[ -f ${FAILED[1]}/log ]]
  [[ $TEST_DIR/fail/dog/$INSTANCE/latest -ef ${FAILED[1]} ]]

  rm -- "$SERVICE/data/.s9/attempt" "$SERVICE/data/ran"
  if S9_WORKING_DIRECTORY="$TEST_DIR/missing" env -C "$SERVICE" -- ./run "$INSTANCE" > "$TEST_DIR/output"; then
    exit 1
  fi
  if [[ -e $SERVICE/data/ran ]]; then
    exit 1
  fi
  [[ -s $TEST_DIR/output ]]
  if [[ -e $TEST_DIR/live/dog/$INSTANCE/log ]]; then
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

  rm -- "$SERVICE/data/.s9/pgid"
  printf -- '%s' -1 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
  for FAILURE in footer archive; do
    TEST_PATH="$PATH"
    case "$FAILURE" in
    archive)
      mv -- "$TEST_DIR/dead/dog" "$TEST_DIR/dead/saved"
      printf -- '%s' blocked > "$TEST_DIR/dead/dog"
      ;;
    footer) TEST_PATH="$TEST_DIR/bin:$PATH" ;;
    *)
      set -x
      exit 2
      ;;
    esac
    ln -sTnfr -- "$SERVICE/data/.run" "$SERVICE/data/.s9/launch"
    if PATH="$TEST_PATH" env -C "$SERVICE" -- ./finish 67 0 "$INSTANCE" > "$TEST_DIR/finish.log"; then
      exit 1
    fi
    if [[ -L $SERVICE/data/.s9/died ]]; then exit 1; fi
    [[ -L $SERVICE/data/.s9/launch ]]
    [[ -f $TEST_DIR/live/dog/$INSTANCE/log ]]
    if [[ $FAILURE == archive ]]; then
      rm -- "$TEST_DIR/dead/dog"
      mv -- "$TEST_DIR/dead/saved" "$TEST_DIR/dead/dog"
    fi
  done
  [[ -f $TEST_DIR/live/dog/$INSTANCE/.s9/record ]]
  ;;
runtime)
  SERVICE="$STATE/dog/instances/walk"
  mkdir -p -- "$SERVICE"
  rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
  printf -- '%s' "$SERVICE" > "$SERVICE/env/S9_WORKING_DIRECTORY"
  printf -- '%s' 10s > "$SERVICE/env/S9_RUNTIME_MAX_SEC"
  cat > "$SERVICE/data/.run" << 'BASH'
#!/usr/bin/env bash
if [[ -n ${RECUR:-} ]]; then exit 67; fi
sleep 30 &
printf -- '%s' "$!" > child
exit 0
BASH
  chmod +x -- "$SERVICE/data/.run"
  trap '
    if [[ -f $SERVICE/data/.s9/pgid ]]; then
      kill -KILL -- "-$(< "$SERVICE/data/.s9/pgid")" 2> /dev/null || true
    fi
    rm -fr -- "$TEST_DIR"
  ' EXIT
  START="$SECONDS"
  STATUS=0
  timeout --foreground 20s s6-setsid -i env -C "$SERVICE" -- ./run walk > "$TEST_DIR/output" || STATUS=$?
  [[ $STATUS == 124 ]]
  ((SECONDS - START < 18))
  [[ -s $SERVICE/child ]]
  CHILD="$(< "$SERVICE/child")"
  kill -0 -- "$CHILD"
  STATUS=0
  env -C "$SERVICE" -- ./finish 124 0 walk > "$TEST_DIR/finish.log" || STATUS=$?
  [[ $STATUS == 125 ]]
  timeout --foreground 2s bash -s -- "$CHILD" << 'BASH'
while kill -0 "$1" 2>/dev/null; do sleep 0.02; done
BASH
  [[ -L $SERVICE/data/.s9/died ]]
  ;;
lifecycle)
  STEP="$TEST_DIR/steps/dog"
  JOB="$JOBS/dog"
  SERVICE="$STATE/dog/instances/walk"
  WAIT=(timeout --foreground 15s bash -c 'until test "$@"; do sleep 0.05; done' --)
  export S9_WORKING_DIRECTORY="$TEST_DIR"
  mkdir -p -- "$STEP/env" "$STEP/data/.s9/launch" "$JOBS/keeper/env"
  printf -- '%s' 10 > "$TEST_DIR/base/env/S9_RUNTIME_MAX_SEC"
  cat > "$STEP/run.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
CODE=old
printf -- '%s:%s:%s\n' "$CODE" "$PAYLOAD" "$(< "${0%/*}/value")" > "$S9_WORKING_DIRECTORY/started-$PAYLOAD"
while ! [[ -f $S9_WORKING_DIRECTORY/release-$PAYLOAD ]]; do sleep 0.05; done
printf -- '%s\n' "$CODE" > "$S9_WORKING_DIRECTORY/finished-$PAYLOAD"
BASH
  chmod +x -- "$STEP/run.sh"
  printf -- '%s' 60 | tee "$STEP/env/S9_ON_UNIT_INACTIVE_SEC" > "$JOBS/keeper/env/S9_ON_UNIT_INACTIVE_SEC"
  printf -- '%s' one > "$STEP/env/PAYLOAD"
  printf -- '%s' old-data > "$STEP/data/value"
  ln -sTnfr -- "$STEP" "$JOB"
  ln -sTnfr -- "$STEP/run.sh" "$STEP/data/.s9/launch/walk"
  RECUR=bootstrap "${QUINE[@]}" quine
  cat > "$JOBS/keeper/run.sh" << 'BASH'
#!/usr/bin/env bash
exit 0
BASH
  chmod +x -- "$JOBS/keeper/run.sh"
  RECUR=seed "${QUINE[@]}" keeper parent
  mkdir -p -- "$STATE/keeper/data/.s9/launch"
  ln -sTnfr -- "$JOBS/keeper/run.sh" "$STATE/keeper/data/.s9/launch/parent"

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
  printf -- '%s' two > "$STEP/env/PAYLOAD"
  printf -- '%s' new-data > "$STEP/data/value"
  "${WAIT[@]}" -s "$TEST_DIR/started-two"
  if [[ -f $TEST_DIR/finished-one ]]; then exit 1; fi
  [[ $(< "$TEST_DIR/started-two") == new:two:new-data ]]

  for ATTEMPT in two three four; do
    case "$ATTEMPT" in
    two) rm -- "$STEP/data/.s9/launch/walk" ;;
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
      printf -- '%s' three > "$STEP/env/PAYLOAD"
      ln -sTnfr -- "$STEP/run.sh" "$STEP/data/.s9/launch/walk"
      "${WAIT[@]}" -s "$TEST_DIR/started-three"
      ;;
    three)
      STEP="$TEST_DIR/removed-step"
      printf -- '%s' four > "$STEP/env/PAYLOAD"
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
  RECORDS=("$TEST_DIR/dead/dog/"*/[0-9]*)
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
  ln -sTnfr -- "$JOBS/quine/run.sh" "$JOBS/quine/data/link"

  RECUR=bootstrap "${QUINE[@]}" quine
  RECUR=seed env -C "$TEST_DIR/snapshot-2" -- ../jobs/quine-2/run.sh quine-2 -
  RECUR=seed env -C "$TEST_DIR/snapshot-3" -- ../services/quine/instances/-/data/.run quine -

  [[ -d $TEST_DIR/snapshot-2/quine-2/template ]]
  if [[ -L $TEST_DIR/snapshot-2/quine-2/template ]]; then
    exit 1
  fi
  LINK="$(readlink -- "$STATE/quine/template/data/link")"
  [[ -L $STATE/quine/template/data/link ]]
  [[ $LINK == ../run.sh ]]

  diff --recursive --no-dereference --unified --from-file="$STATE/quine" -- "$TEST_DIR/snapshot-2/quine-2" "$TEST_DIR/snapshot-3/quine"
  ;;

p-cp)
  PCP="$TEST_DIR/libexec/p-cp.sh"
  SRC="$TEST_DIR/source"
  DST="$TEST_DIR/output/dog"
  mkdir -p -- "$SRC/nested" "$TEST_DIR/external" "$DST"
  printf -- '%s' original > "$SRC/value"
  printf -- '%s' first > "$TEST_DIR/external/first"
  printf -- '%s' second > "$TEST_DIR/external/second"
  printf -- '%s' existing > "$DST/value"
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
  printf -- '%s' changed > "$SRC/value"
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
  printf -- '%s' arrived > "$TEST_DIR/missing"
  [[ $(< "$DST/dangling") == arrived ]]
  mv -- "$TEST_DIR/output" "$TEST_DIR/relocated"
  DST="$TEST_DIR/relocated/dog"
  [[ $(< "$DST/nested/internal") == original ]]
  [[ $(< "$DST/absolute-internal") == original ]]
  [[ $(< "$DST/nested/external") == second ]]
  ;;
publication)
  mkdir -p -- "$TEST_DIR/bin" "$TEST_DIR/old/data/.s9/launch" "$TEST_DIR/new/data/.s9/launch"
  for REVISION in old new; do
    printf -- '#!/usr/bin/env bash\nprintf -- "%s\\n"\n' "$REVISION" > "$TEST_DIR/$REVISION/run.sh"
    chmod +x -- "$TEST_DIR/$REVISION/run.sh"
    ln -sTnf -- "/$REVISION" "$TEST_DIR/$REVISION/data/.s9/launch/walk"
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
  printf -- '%s\n' "${TEST_SERVICE_STATUS:-false false}"
  ;;
s6-instance-control)
  if [[ $1 == -d ]]; then
    printf -- 'stop\n' >> "$TEST_ROOT/stops"
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
  [[ -L $STATE/dog/template/data/.s9/source ]]
  TARGET="$(readlink -- "$STATE/dog/template/data/.s9/source")"
  [[ $TARGET == "$TEST_DIR/old" ]]
  TARGET="$(readlink -- "$SERVICE/data/.s9/source")"
  [[ $TARGET == "$TEST_DIR/old" ]]
  TARGET="$(readlink -- "$SERVICE/data/.s9/launch")"
  [[ $TARGET == /old ]]
  [[ -L $TEST_DIR/new/data/.s9/launch/walk ]]
  if [[ -L $TEST_DIR/old/data/.s9/launch/walk ]]; then exit 1; fi

  mkdir -p -- "$JOBS/consumer/data/wants"
  cp -- "$TEST_DIR/old/run.sh" "$JOBS/consumer/run.sh"
  ln -sTnfr -- "$TEST_DIR/old" "$JOBS/consumer/data/wants/dog"
  RECUR=seed "${QUINE[@]}" consumer -
  "$TEST_DIR/base/data/topology.sh" compile "$TEST_DIR" "$JOBS"
  [[ -L $TEST_DIR/graph/topology/wants/consumer/dog ]]
  [[ $TEST_DIR/graph/topology/wants/consumer/dog -ef $TEST_DIR/graph/topology/wants/dog ]]
  if [[ -d $STATE/consumer/data/.s9/launch ]]; then exit 1; fi

  ln -sTnfr -- "$TEST_DIR/dead/dog/walk/removed" "$SERVICE/data/.s9/died"
  if TEST_DELETE_STATUS=111 "${RECONCILE[@]}"; then exit 1; fi
  [[ -d $SERVICE ]]
  [[ -L $SERVICE/data/.s9/died ]]
  [[ -L $TEST_DIR/new/data/.s9/launch/walk ]]
  "${RECONCILE[@]}"
  diff --unified -- "$TEST_DIR/new/run.sh" "$SERVICE/data/.run"
  TARGET="$(readlink -- "$SERVICE/data/.s9/launch")"
  [[ $TARGET == /new ]]
  if [[ -L $SERVICE/data/.s9/died ]]; then exit 1; fi

  printf -- '%s' 0 > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
  TEST_SERVICE_STATUS='true true' "${RECONCILE[@]}"
  [[ -d $SERVICE ]]
  TEST_SERVICE_STATUS='true false' "${RECONCILE[@]}"
  [[ -d $SERVICE ]]
  [[ $(< "$TEST_DIR/stops") == stop ]]
  "${RECONCILE[@]}"
  if [[ -d $SERVICE ]]; then exit 1; fi

  mkdir -p -- "$TEST_DIR/new/env"
  printf -- '%s' 0 > "$TEST_DIR/new/env/S9_ON_UNIT_INACTIVE_SEC"
  ln -sTnf -- /new "$TEST_DIR/new/data/.s9/launch/walk"
  "${RECONCILE[@]}"
  touch -- "$SERVICE/stale"
  TEST_SUPERVISOR_STATUS=1 "${RECONCILE[@]}"
  [[ -d $SERVICE ]]
  if [[ -e $SERVICE/stale ]]; then exit 1; fi
  [[ -L $TEST_DIR/new/data/.s9/launch/walk ]]
  diff --unified -- "$TEST_DIR/new/run.sh" "$SERVICE/data/.run"

  printf -- '%s' payload > "$TEST_DIR/new/data/payload"
  ln -sTnfr -- "$TEST_DIR/new/data/payload" "$TEST_DIR/new/data/.s9/launch/mail"
  printf -- '%s' -1 > "$TEST_DIR/new/env/S9_ON_UNIT_INACTIVE_SEC"
  "${RECONCILE[@]}"
  [[ $(< "$STATE/dog/instances/mail/data/.s9/launch") == payload ]]
  if [[ -L $TEST_DIR/new/data/.s9/launch/mail ]]; then exit 1; fi

  LIVE="$TEST_DIR/live/dog/mail"
  RECORD="$TEST_DIR/dead/dog/mail/20261005T000000.000000000"
  mkdir -p -- "$LIVE/outputs/row" "$LIVE/.s9" "${RECORD%/*}"
  printf -- '%s' payload > "$LIVE/outputs/row/value"
  printf -- '%s' 0 > "$LIVE/exit_status"
  printf -- '%s' 0 > "$LIVE/signal"
  printf -- '%s' "$RECORD" > "$LIVE/.s9/record"
  DEFINITION="$(< "$STATE/dog/instances/mail/data/.s9/defs.sum")"
  printf -- '%s' blocked > "$RECORD"
  TEST_SUPERVISOR_STATUS=1 "${RECONCILE[@]}" > "$TEST_DIR/output" 2>&1
  [[ -s $TEST_DIR/output ]]
  [[ -f $STATE/dog/instances/mail/data/.s9/defs.sum ]]
  [[ -L $STATE/dog/instances/mail/data/.s9/launch ]]
  [[ -f $LIVE/.s9/record ]]
  rm -- "$RECORD"
  TEST_SUPERVISOR_STATUS=1 "${RECONCILE[@]}"
  [[ $(< "$RECORD/outputs/row/value") == payload ]]
  [[ $(< "$RECORD/outputs/row/.s9/defs.sum") == "$DEFINITION" ]]
  [[ $TEST_DIR/dead/dog/mail/latest-succ -ef $RECORD ]]
  if [[ -d $STATE/dog/instances/mail ]] || [[ -d $LIVE ]]; then exit 1; fi
  ;;
templates)
  JOB="$JOBS/dog"
  mkdir -p -- "$JOB/env" "$JOB/data/.s9/launch"
  cat > "$JOB/run.sh" << 'BASH'
#!/usr/bin/env bash
set -euo pipefail
printf -- '%s:%s:%s\n' "$1" "$PAYLOAD" "$(< "${0%/*}/value")"
BASH
  chmod +x -- "$JOB/run.sh"
  printf -- '%s' first > "$JOB/env/PAYLOAD"
  printf -- '%s' original > "$JOB/data/value"
  ln -sTnfr -- "$JOB/run.sh" "$JOB/data/.s9/launch/walk"
  ln -sTnfr -- "$JOB" "$JOBS/lil"
  for NAME in dog lil; do
    RECUR=seed "${QUINE[@]}" "$NAME" walk
    SERVICE="$STATE/$NAME/instances/walk"
    diff --unified -- "$JOB/run.sh" "$SERVICE/data/.run"
    diff --unified -- "$JOB/env/PAYLOAD" "$SERVICE/env/PAYLOAD"
    [[ $SERVICE/run -ef $SERVICE/data/lifecycle.sh ]]
    if [[ -e $SERVICE/data/.s9/launch ]] || [[ -L $SERVICE/data/.s9/launch ]]; then exit 1; fi
    if [[ -L $SERVICE/data/.run ]]; then exit 1; fi
    ACTUAL="$(s6-envdir -- "$SERVICE/env" "$SERVICE/data/.run" walk)"
    [[ $ACTUAL == walk:first:original ]]
  done
  RECUR=seed "${QUINE[@]}" dog walk
  diff --unified -- "$STATE/dog/template/data/.s9/defs.sum" "$STATE/dog/instances/walk/data/.s9/defs.sum"
  mkdir -- "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/rsync" << 'BASH'
#!/usr/bin/env bash
exit 67
BASH
  chmod +x -- "$TEST_DIR/bin/rsync"
  ln -sTnfr -- "$JOB/run.sh" "$JOB/data/.s9/launch/another"
  mkdir -p -- "$JOB/data/.s9"
  printf -- '%s' ignored > "$JOB/data/.s9/runtime"
  touch -- "$JOB/run.sh"
  PATH="$TEST_DIR/bin:$PATH" RECUR=seed "${QUINE[@]}" dog walk
  cat > "$TEST_DIR/bin/tar" << 'BASH'
#!/usr/bin/env bash
for ARG in "$@"; do
  if [[ $ARG == --dereference ]]; then exit 67; fi
done
exec -- "$REAL_TAR" "$@"
BASH
  chmod +x -- "$TEST_DIR/bin/tar"
  REAL_TAR="$(command -v tar)"
  STATUS=0
  REAL_TAR="$REAL_TAR" PATH="$TEST_DIR/bin:$PATH" RECUR=seed "${QUINE[@]}" dog walk > "$TEST_DIR/output" 2>&1 || STATUS=$?
  [[ $STATUS == 67 ]]
  rm -- "$TEST_DIR/bin/tar"
  printf -- '%s' interrupted > "$JOB/env/PAYLOAD"
  if PATH="$TEST_DIR/bin:$PATH" RECUR=seed "${QUINE[@]}" dog walk > "$TEST_DIR/output" 2>&1; then exit 1; fi
  if [[ -f $STATE/dog/data/.s9/inputs.sum ]]; then exit 1; fi
  printf -- '%s' first > "$JOB/env/PAYLOAD"
  RECUR=seed "${QUINE[@]}" dog walk
  BEFORE="$(< "$STATE/dog/template/data/.s9/defs.sum")"
  printf -- '\n' >> "$JOB/run.sh"
  RECUR=seed "${QUINE[@]}" dog walk
  [[ $(< "$STATE/dog/template/data/.s9/defs.sum") != "$BEFORE" ]]
  BEFORE="$(< "$STATE/dog/template/data/.s9/defs.sum")"
  printf -- '%s' changed > "$TEST_DIR/base/env/S9_RESTART_SEC"
  RECUR=seed "${QUINE[@]}" dog walk
  [[ $(< "$STATE/dog/template/data/.s9/defs.sum") != "$BEFORE" ]]
  [[ $(< "$STATE/dog/template/env/S9_RESTART_SEC") == changed ]]
  rm -- "$JOB/env/PAYLOAD" "$JOB/data/value"
  RECUR=seed "${QUINE[@]}" dog walk
  if [[ -e $STATE/dog/template/env/PAYLOAD ]] || [[ -e $STATE/dog/template/data/value ]]; then exit 1; fi
  SERVICE="$STATE/dog/instances/walk"
  ACTUAL="$(s6-envdir -- "$SERVICE/env" "$SERVICE/data/.run" walk)"
  [[ $ACTUAL == walk:first:original ]]

  mkdir -p -- "$JOB/data/wants"
  ln -sTnfr -- "$JOBS/absent/producer" "$JOB/data/wants/unknown"
  RECUR=seed "${QUINE[@]}" dog missing
  TARGET="$(readlink -- "$STATE/dog/instances/missing/data/wants/unknown")"
  [[ $TARGET == "$JOBS/absent/producer" ]]
  ;;

queues)
  STEP="$TEST_DIR/queue-step"
  JOB="$JOBS/queue-dog"
  LAUNCH="$JOB/data/.s9/launch"
  MANAGER="$STATE/queue-dog"
  mkdir -p -- "$STEP/data/.s9/launch" "$TEST_DIR/bin"
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
printf -- '%s\n' "${TEST_STATUS:-true}"
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
  ln -sTnfr -- "$STEP/run.sh" "$LAUNCH/.pending"
  "${RECONCILE[@]}" queue-dog
  [[ -d $MANAGER/instances/run ]]
  [[ -L $MANAGER/instances/run/data/.s9/launch ]]
  if [[ -L $LAUNCH/run ]] || [[ -d $MANAGER/instances/.pending ]]; then
    exit 1
  fi
  [[ -L $LAUNCH/.pending ]]

  mkdir -- "$TEST_DIR/stale" "$TEST_DIR/current"
  mkdir -p -- "$TEST_DIR/stale/.s9" "$TEST_DIR/current/.s9"
  printf -- '%s' stale > "$TEST_DIR/stale/.s9/defs.sum"
  cp -- "$MANAGER/template/data/.s9/defs.sum" "$TEST_DIR/current/.s9/defs.sum"
  ln -sTnfr -- "$TEST_DIR/stale" "$LAUNCH/stale"
  ln -sTnfr -- "$TEST_DIR/current" "$LAUNCH/current"
  "${RECONCILE[@]}" queue-dog
  if [[ -L $LAUNCH/stale ]] || [[ -d $MANAGER/instances/stale ]]; then exit 1; fi
  [[ -L $MANAGER/instances/current/data/.s9/launch ]]

  ln -sTnfr -- "$STEP/run.sh" "$LAUNCH/rejected"
  if "${RECONCILE[@]}" queue-dog; then
    exit 1
  fi
  [[ -L $LAUNCH/rejected ]]
  if [[ -L $LAUNCH/run ]]; then
    exit 1
  fi

  ln -sTnfr -- "$STEP/run.sh" "$LAUNCH/run"
  if env -C "$MANAGER/instances/run" -- ./finish 0 0 run > "$TEST_DIR/finish.log"; then
    exit 1
  else
    [[ $? == 125 ]]
  fi
  [[ -L $LAUNCH/run ]]
  [[ -L $MANAGER/instances/run/data/.s9/died ]]
  [[ $(< "$MANAGER/instances/run/data/.s9/died/exit_status") == 0 ]]
  if [[ -L $MANAGER/instances/run/data/.s9/launch ]]; then
    exit 1
  fi

  mkdir -- "$STEP/env"
  printf -- '%s' 0 > "$STEP/env/S9_ON_UNIT_INACTIVE_SEC"
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
  printf -- '%s' changed > "$STEP/env/PAYLOAD"
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
  mkdir -p -- "$SERVICE" "$TEST_DIR/bin"
  rsync --archive --copy-unsafe-links -- "$TEST_DIR/base/" "$SERVICE/"
  printf -- '%s' "$SERVICE" > "$SERVICE/env/S9_WORKING_DIRECTORY"
  printf -- '%s' 2 > "$SERVICE/env/S9_RESTART_SEC"
  cat > "$SERVICE/data/.run" << 'BASH'
#!/usr/bin/env bash
printf -- '%s' "$1"
BASH
  cat > "$TEST_DIR/bin/sleep" << 'BASH'
#!/usr/bin/env bash
printf -- '%s' "${@: -1}" > ./delay
BASH
  chmod +x -- "$SERVICE/data/.run" "$TEST_DIR/bin/sleep"
  TEST_BIN="$(realpath -- "$TEST_DIR/bin")"
  ln -sTnfr -- "$SERVICE/data/.run" "$SERVICE/data/.s9/launch"
  trap 'printf "policy:%s interval=%s cap=%s status=%s delay=%s exit=%s attempts=%s: %s\n" "$LINENO" "$INTERVAL" "$CAP" "$STATUS" "$DELAY" "$EXPECTED_EXIT" "$EXPECTED_ATTEMPTS" "$BASH_COMMAND" >&2' ERR
  while read -r INTERVAL CAP STATUS DELAY EXPECTED_EXIT EXPECTED_ATTEMPTS; do
    printf -- '%s' "$INTERVAL" > "$SERVICE/env/S9_ON_UNIT_INACTIVE_SEC"
    printf -- '%s' "${CAP#-}" > "$SERVICE/env/S9_RESTART_MAX_DELAY_SEC"
    rm -f -- "$SERVICE/delay"
    PATH="$TEST_BIN:$PATH" env -C "$SERVICE" -- ./run walk > "$TEST_DIR/output"
    if [[ -s $TEST_DIR/output ]]; then
      exit 1
    fi
    grep --quiet --fixed-strings 'dog@walk walk' "$TEST_DIR/live/dog/walk/log"
    ACTUAL_DELAY=none
    if [[ -f $SERVICE/delay ]]; then ACTUAL_DELAY="$(< "$SERVICE/delay")"; fi
    [[ $ACTUAL_DELAY == "$DELAY" ]]
    rm -- "$SERVICE/data/.s9/pgid"
    EXIT_STATUS=0
    env -C "$SERVICE" -- ./finish "$STATUS" 0 walk > "$TEST_DIR/finish.log" || EXIT_STATUS=$?
    ((EXIT_STATUS == EXPECTED_EXIT))
    ATTEMPT="$(wc -l < "$SERVICE/data/.s9/attempt")"
    ((ATTEMPT == EXPECTED_ATTEMPTS))
    if ((EXIT_STATUS == 0)); then [[ -L $SERVICE/data/.s9/launch ]]; fi
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
  [[ -L $SERVICE/data/.s9/died ]]
  [[ $(< "$SERVICE/data/.s9/died/exit_status") == 0 ]]
  if [[ -L $SERVICE/data/.s9/launch ]]; then
    exit 1
  fi
  ;;
*)
  set -x
  exit 2
  ;;
esac
