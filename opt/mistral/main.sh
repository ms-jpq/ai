#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="${0%/*}"
PYTHONPATH="$BASE/mistral-src" exec -- "$BASE/.venv/bin/python3" -m main demo "$BASE/../../mnt"/mistral-*/

