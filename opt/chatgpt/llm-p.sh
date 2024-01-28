#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

exec -- edit.sh "${0%/*}/../../etc/prompts/$*.txt"
