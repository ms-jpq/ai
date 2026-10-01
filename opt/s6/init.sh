#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

MODE="$1"
shift -- 1
STATE="$1"

LOGS="$STATE/../log/s6.log"
mkdir -p -- "$STATE" "$LOGS"

case "$MODE" in
compile)
  WORKSPACE="$2"
  BASE="$(realpath -- "${0%/*}")"
  RSYNC=(rsync --archive --copy-links --checksum)

  find "$STATE" -mindepth 1 -maxdepth 1 ! -name .s6-svscan -exec rm -rf -- '{}' +
  mkdir -p -- "$STATE/.env"
  printf -- '%s' "$WORKSPACE" > "$STATE/.env/S67_WORKSPACE"

  for LAYER in "$BASE" "$WORKSPACE/.claude/s6"; do
    for JOB in "$LAYER/jobs/"*; do
      if [[ -x $JOB/run ]]; then
        DEST="$STATE/${JOB##*/}"
        "${RSYNC[@]}" --delete -- "$BASE/base/" "$DEST/"
        cp -L -- "$JOB/run" "$DEST/data/job"
        if [[ -d $JOB/env ]]; then
          "${RSYNC[@]}" -- "$JOB/env/" "$DEST/env/"
        fi
      fi
    done
    for SERVICE in "$LAYER/overlay/"*/; do
      NAME="${SERVICE%/}"
      NAME="${NAME##*/}"
      "${RSYNC[@]}" --delete -- "$SERVICE" "$STATE/$NAME/"
    done
  done
  ;;
start)
  "$0" shutdown "$@"
  "$0" compile "$@"
  s6-envdir -f -n "$STATE/.env" s6-svscan "$STATE" 2>&1 | s6-log -b T "$LOGS"
  ;;
shutdown)
  if ! [[ -p $STATE/.s6-svscan/control ]]; then
    exit
  fi

  if s6-svscanctl -t "$STATE"; then
    s6-setlock "$STATE/.s6-svscan/lock" true
  else
    STATUS=$?
    if ((STATUS != 100)); then
      exit "$STATUS"
    fi
  fi
  ;;
stat)
  for SERVICE in "$STATE/"[!.]*/; do
    printf -- '%s: ' "${SERVICE%/}"
    s6-svstat "$SERVICE"
  done
  ;;
*)
  set -x
  exit 2
  ;;
esac
