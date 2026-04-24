#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

BASE="$(realpath -- "$0")"
ROOT="${BASE%/*}/../.."

set -a
# shellcheck disable=SC1091
source -- "$ROOT/.env"
set +a

export -- LC_ALL='en_CA.UTF-8' OPENCODE_CONFIG_DIR="$ROOT/var/opencode" OPENCODE_DISABLE_LSP_DOWNLOAD=1
exec -- "$ROOT/opt/libexec/harness.sh" "$ROOT/node_modules/.bin/opencode" "$@"
