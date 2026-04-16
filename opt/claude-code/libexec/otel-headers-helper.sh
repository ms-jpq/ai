#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# shellcheck disable=SC2154
TOKEN="$(base64 -w0 <<< "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY")"

tee <<- JSON
{"Authorization": "Basic $TOKEN", "x-langfuse-ingestion-version": "4"}
JSON
