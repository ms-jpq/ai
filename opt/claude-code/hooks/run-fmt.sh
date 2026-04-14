#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

FILE_PATH="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"

case "$FILE_PATH" in
*.json)
  jq empty -- "$FILE_PATH" || exit 2
  ;;
*.toml)
  RUST_LOG=warn taplo format -- "$FILE_PATH" || exit 2
  ;;
*.sh)
  shfmt --simplify --binary-next-line --space-redirects --indent=2 --write -- "$FILE_PATH" || exit 2
  ;;
*.lua)
  stylua --syntax=LuaJit --indent-type=Spaces --indent-width=2 --sort-requires --call-parentheses=None -- "$FILE_PATH" || exit 2
  ;;
*.link | *.netdev | *.network | *.socket | *.service | *.target | *.mount | *.automount | *.dnssd)
  SYSTEMD_FMT_MODE='stream' systemd-fmt.sh "$FILE_PATH" || exit 2
  ;;
*/repart.d/*.conf | */systemd/**/*.conf | */*.network.d/*.conf)
  SYSTEMD_FMT_MODE='stream' systemd-fmt.sh "$FILE_PATH" || exit 2
  ;;
*)
  exit 0
  ;;
esac >&2
