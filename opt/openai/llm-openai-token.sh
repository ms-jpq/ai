#!/usr/bin/env -S -- bash -Eeu -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

NETRC="$HOME/.netrc"
if ! grep -F -- 'openai.com' "$NETRC" > /dev/null 2>&1; then
  tee -- "$NETRC" <<- EOF
machine api.openai.com
  password
EOF
  edit.sh "$NETRC"
  chmod 0600 "$NETRC"
fi
