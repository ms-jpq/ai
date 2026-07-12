#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"

exec -- "${BASE%/*}/../../.venv/bin/huggingface-cli" "$@"
