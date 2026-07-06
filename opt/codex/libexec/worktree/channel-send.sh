#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail
shopt -u failglob

if TOP="$(git rev-parse --show-toplevel)" && [[ -d "$TOP/.notes/.channels" ]]; then
  DIR="$TOP/.notes/.channels"
else
  exit
fi

SOCKS=("$DIR"/*.sock)
if ((${#SOCKS[@]} == 0)); then
  printf -- 'no live channels in %s\n' "$DIR" >&2
  exit 1
fi

MSG="$*"
if [[ -z $MSG ]]; then
  MSG="$(tee)"
fi

NC=(nc -N -U --)
DELIVERED=0
for SOCK in "${SOCKS[@]}"; do
  if printf -- '%s\n' "$MSG" | "${NC[@]}" "$SOCK" 2> /dev/null; then
    printf -- 'sent: %s\n' "${SOCK##*/}" >&2
    DELIVERED=$((DELIVERED + 1))
  else
    printf -- 'stale: %s — removed\n' "${SOCK##*/}" >&2
    rm -f -- "$SOCK"
  fi
done

((DELIVERED > 0))
