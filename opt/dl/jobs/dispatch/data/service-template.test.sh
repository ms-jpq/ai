#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
trap 'printf "%s:%s: %s\n" "$0" "$LINENO" "$BASH_COMMAND" >&2' ERR

TEMPLATE="${1:-${0%.test.sh}.sh}"
mkdir -p -- "${0%/*}/../../../../../var/tmp"
TEST_DIR="$(mktemp -d -- "${0%/*}/../../../../../var/tmp/service-template-test.XXXXXX")"
trap 'rm -fr -- "$TEST_DIR"' EXIT
SRC="$TEST_DIR/steps/dog house"
DST="$TEST_DIR/jobs/dog house"
mkdir -p -- "$SRC/requests/"{recurring,oneshot} "$SRC/data/inbox" "$SRC/wants" "$TEST_DIR/steps/lil"
ln -s -- ../../lil "$SRC/wants/lil"
ln -s -- /missing/old-records "$SRC/data/inbox/lil"
cat > "$SRC/run.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x -- "$SRC/run.sh"
ln -s -- ../../data/inbox "$SRC/requests/oneshot/initial"

"$TEMPLATE" "$SRC" "$DST"
FIRST="$(realpath -- "$DST")"
INBOX="$(readlink -- "$DST/data/inbox/lil")"
DEPENDENCY="$(realpath -- "$TEST_DIR/steps/lil")"
[[ $INBOX == "$DEPENDENCY/records" ]]
mkdir -p -- "$TEST_DIR/steps/lil/records/walk/revision/output"
ln -s -- revision "$TEST_DIR/steps/lil/records/walk/latest"
[[ $DST/data/inbox/lil/walk/latest/output -ef $TEST_DIR/steps/lil/records/walk/revision/output ]]
for MODE in recurring oneshot; do
  [[ -L $DST/data/$MODE ]]
  [[ $DST/data/$MODE -ef $SRC/requests/$MODE ]]
  ln -s -- ../../data/inbox "$DST/data/$MODE/queued request"
  ln -s -- /missing/inbox "$DST/data/$MODE/.pending"
done
rm -- "$DST/data/oneshot/initial"
if [[ -L $SRC/requests/oneshot/initial ]]; then
  exit 1
fi

cat > "$SRC/run.sh" << 'EOF'
#!/usr/bin/env bash
exit 67
EOF
for _ in 1 2 3; do
  "$TEMPLATE" "$SRC" "$DST"
  CURRENT="$(realpath -- "$DST")"
  [[ $CURRENT != "$FIRST" ]]
  diff --unified -- "$SRC/run.sh" "$DST/data/command"
  for MODE in recurring oneshot; do
    [[ -L $DST/data/$MODE/queued\ request ]]
    [[ -L $DST/data/$MODE ]]
    [[ $DST/data/$MODE -ef $FIRST/data/$MODE ]]
    [[ $DST/data/$MODE/queued\ request -ef $SRC/data/inbox ]]
    [[ -L $DST/data/$MODE/.pending ]]
  done
  if [[ -L $DST/data/oneshot/initial ]]; then
    exit 1
  fi
done
"$FIRST/data/command"

ln -s -- /dev/null "$FIRST/data/oneshot/late"
[[ -L $DST/data/oneshot/late ]]
rm -- "$DST/data/oneshot/queued request"
"$TEMPLATE" "$SRC" "$DST"
if [[ -L $DST/data/oneshot/queued\ request ]]; then
  exit 1
fi
[[ -L $DST/data/recurring/queued\ request ]]
[[ -L $DST/data/oneshot/late ]]

BEFORE="$(readlink -- "$DST")"
chmod -x -- "$SRC/run.sh"
if "$TEMPLATE" "$SRC" "$DST" 2> "$TEST_DIR/error"; then
  exit 1
else
  [[ $? == 2 ]]
fi
AFTER="$(readlink -- "$DST")"
[[ $BEFORE == "$AFTER" ]]
[[ -L $DST/data/oneshot/late ]]

chmod +x -- "$SRC/run.sh"
ln -s -- /missing/dependency "$SRC/wants/missing"
if "$TEMPLATE" "$SRC" "$DST" 2> "$TEST_DIR/error"; then
  exit 1
fi
AFTER="$(readlink -- "$DST")"
[[ $AFTER == "$BEFORE" ]]
