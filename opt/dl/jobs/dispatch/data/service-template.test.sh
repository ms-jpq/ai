#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
trap 'printf "%s:%s: %s\n" "$0" "$LINENO" "$BASH_COMMAND" >&2' ERR

TEMPLATE="${1:-${0%.test.sh}.sh}"
mkdir -p -- "${0%/*}/../../../../../var/tmp"
TEST_DIR="$(mktemp -d -- "${0%/*}/../../../../../var/tmp/service-template-test.XXXXXX")"
trap 'rm -fr -- "$TEST_DIR"' EXIT
SRC="$TEST_DIR/steps/dog house"
DST="$TEST_DIR/jobs/dog house"
mkdir -p -- "$SRC/queue/"{recurring,oneshot} "$SRC/data/inbox"
cat > "$SRC/run.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x -- "$SRC/run.sh"
ln -s -- ../../data/inbox "$SRC/queue/oneshot/initial"

"$TEMPLATE" "$SRC" "$DST"
FIRST="$(realpath -- "$DST")"
for MODE in recurring oneshot; do
  [[ -L $DST/data/$MODE ]]
  [[ $DST/data/$MODE -ef $SRC/queue/$MODE ]]
  ln -s -- ../../data/inbox "$DST/data/$MODE/queued request"
  ln -s -- /missing/inbox "$DST/data/$MODE/.pending"
done
rm -- "$DST/data/oneshot/initial"
if [[ -L $SRC/queue/oneshot/initial ]]; then
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
