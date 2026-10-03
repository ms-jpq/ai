#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
trap 'printf "%s:%s: %s\n" "$0" "$LINENO" "$BASH_COMMAND" >&2' ERR

TEMPLATE="${1:-${0%.test.sh}.sh}"
mkdir -p -- "${0%/*}/../../../../../var/tmp"
TEST_DIR="$(mktemp -d -- "${0%/*}/../../../../../var/tmp/service-template-test.XXXXXX")"
trap 'rm -fr -- "$TEST_DIR"' EXIT
SRC="$TEST_DIR/steps/dog house"
DST="$TEST_DIR/jobs/dog house"
LAUNCH="$DST/data/launch"
SOURCE_LAUNCH="$SRC/launch"
DEPENDENCY="$TEST_DIR/steps/lil"
mkdir -p -- "$SOURCE_LAUNCH" "$SRC/data/inbox" "$SRC/wants" "$DEPENDENCY"
ln -s -- ../../lil "$SRC/wants/lil"
ln -s -- /missing/old-records "$SRC/data/inbox/lil"
cat > "$SRC/run.sh" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x -- "$SRC/run.sh"
ln -s -- ../data/inbox "$SOURCE_LAUNCH/initial"

"$TEMPLATE" "$SRC" "$DST"
FIRST="$(realpath -- "$DST")"
INBOX="$(readlink -- "$DST/data/inbox/lil")"
DEPENDENCY="$(realpath -- "$DEPENDENCY")"
[[ $INBOX == "$DEPENDENCY/records" ]]
mkdir -p -- "$DEPENDENCY/records/walk/revision/output"
ln -s -- revision "$DEPENDENCY/records/walk/latest"
[[ $DST/data/inbox/lil/walk/latest/output -ef $DEPENDENCY/records/walk/revision/output ]]
[[ -L $LAUNCH ]]
[[ $LAUNCH -ef $SOURCE_LAUNCH ]]
ln -s -- ../data/inbox "$LAUNCH/queued request"
ln -s -- /missing/inbox "$LAUNCH/.pending"
rm -- "$LAUNCH/initial"
if [[ -L $SOURCE_LAUNCH/initial ]]; then
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
  [[ -L $LAUNCH ]]
  [[ $LAUNCH -ef $FIRST/data/launch ]]
  [[ -L $LAUNCH/queued\ request ]]
  [[ $LAUNCH/queued\ request -ef $SRC/data/inbox ]]
  [[ -L $LAUNCH/.pending ]]
  if [[ -L $LAUNCH/initial ]]; then
    exit 1
  fi
done
"$FIRST/data/command"

ln -s -- /dev/null "$FIRST/data/launch/late"
[[ -L $LAUNCH/late ]]
rm -- "$LAUNCH/queued request"
"$TEMPLATE" "$SRC" "$DST"
if [[ -L $LAUNCH/queued\ request ]]; then
  exit 1
fi
[[ -L $LAUNCH/late ]]

BEFORE="$(readlink -- "$DST")"
chmod -x -- "$SRC/run.sh"
if "$TEMPLATE" "$SRC" "$DST" 2> "$TEST_DIR/error"; then
  exit 1
else
  [[ $? == 2 ]]
fi
AFTER="$(readlink -- "$DST")"
[[ $BEFORE == "$AFTER" ]]
[[ -L $LAUNCH/late ]]

chmod +x -- "$SRC/run.sh"
ln -s -- /missing/dependency "$SRC/wants/missing"
if "$TEMPLATE" "$SRC" "$DST" 2> "$TEST_DIR/error"; then
  exit 1
fi
AFTER="$(readlink -- "$DST")"
[[ $AFTER == "$BEFORE" ]]
