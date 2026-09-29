#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

STATE="$1"
shift -- 1
: "$1"

mkdir -p -- "$STATE"
STATE="$(realpath -- "$STATE")"
CURRENT="$STATE/current"
PENDING="$STATE/pending.txt"

if [[ -f $PENDING ]]; then
  exec -- cat -- "$PENDING"
fi

NEXT="$(mktemp -d "$STATE/next.XXXXXX")"
trap 'rm -rf -- "$NEXT"' EXIT
SOURCES=()
for SOURCE in "$@"; do
  SOURCE="$(realpath --canonicalize-missing --no-symlinks -- "$SOURCE")"
  RESOLVED="$(realpath --canonicalize-missing -- "$SOURCE")"
  if [[ $RESOLVED == / || $STATE == "$RESOLVED" || $STATE == "$RESOLVED/"* ]]; then
    printf -- 'Snapshot directory must be outside instruction sources: %s\n' "$SOURCE" >&2
    exit 2
  fi
  SOURCES+=("$SOURCE")
done

mkdir -p -- "$NEXT/tree"
env -C "$NEXT/tree" -- rsync --recursive --copy-links --relative --ignore-missing-args -- "${SOURCES[@]}" .

if ! [[ -d $CURRENT ]]; then
  mv -- "$NEXT/tree" "$CURRENT"
  exit
fi

find "$CURRENT" "$NEXT/tree" -type f -printf '%P\0' | sort --zero-terminated --unique > "$NEXT/paths"

while IFS= read -r -d '' FILE; do
  BEFORE="$CURRENT/$FILE"
  AFTER="$NEXT/tree/$FILE"
  if [[ -f $BEFORE && -f $AFTER ]]; then
    if cmp --silent -- "$BEFORE" "$AFTER"; then
      continue
    else
      STATUS=$?
      if ((STATUS != 1)); then
        exit "$STATUS"
      fi
    fi
  fi

  if [[ -f $AFTER ]]; then
    printf -- 'Updated instruction file: /%s\n\n' "$FILE"
    cat -- "$AFTER"
    printf -- '\n\n'
  else
    printf -- 'Removed instruction file: /%s\n\n' "$FILE"
  fi
done < "$NEXT/paths" > "$NEXT/changes.txt"

if [[ -s $NEXT/changes.txt ]]; then
  tee > "$NEXT/context.txt" << EOF
<system-reminder>
Instruction files changed. Use these updates within their original scope and precedence. Preserve any path conditions in their frontmatter.

$(< "$NEXT/changes.txt")
</system-reminder>
EOF
  mv -- "$NEXT/context.txt" "$PENDING"
fi

env -C "$CURRENT" -- rsync --recursive --checksum --delete -- "$NEXT/tree/" .

if [[ -f $PENDING ]]; then
  cat -- "$PENDING"
fi
