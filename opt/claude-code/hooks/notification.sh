#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s dotglob nullglob extglob globstar

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

exec -- "${0%/*}/../libexec/notify.sh" <<< "$JSON"
