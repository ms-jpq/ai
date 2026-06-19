#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

JSON="$(tee)"
# "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"

FILE_PATH="$(jq -e --raw-output '.tool_input.file_path' <<< "$JSON")"

case "$FILE_PATH" in
*.awk)
  awk-fmt < "$FILE_PATH" | sponge -- "$FILE_PATH" || exit 2
  ;;
*.link | *.netdev | *.network | *.socket | *.service | *.target | *.mount | *.automount | *.dnssd)
  systemd-fmt.sh "$FILE_PATH" > /dev/null || exit 2
  ;;
*/repart.d/*.conf | */systemd/**/*.conf | */*.network.d/*.conf)
  systemd-fmt.sh "$FILE_PATH" > /dev/null || exit 2
  ;;
*.json | *.jsonl)
  jq --sort-keys -- . < "$FILE_PATH" | sponge -- "$FILE_PATH" || exit 2
  ;;
*.toml)
  if command -v -- taplo > /dev/null; then
    RUST_LOG=warn taplo format -- "$FILE_PATH" || exit 2
  fi
  ;;
*.sh | *.bash)
  if command -v -- shfmt > /dev/null; then
    shfmt --simplify --binary-next-line --space-redirects --indent=2 --write -- "$FILE_PATH" || exit 2
  fi
  if command -v -- shellcheck > /dev/null; then
    shellcheck --shell=bash -- "$FILE_PATH" || exit 2
  fi
  ;;
*Dockerfile | *Dockerfile.* | *.dockerfile | *Containerfile)
  if command -v -- hadolint > /dev/null; then
    hadolint -- "$FILE_PATH" || exit 2
  fi
  ;;
*.pl | *.pm | *.t)
  if command -v -- perltidy > /dev/null; then
    RC=0
    perltidy --standard-error-output --backup-and-modify-in-place --backup-file-extension=/ --indent-columns=2 --output-line-ending=unix -- "$FILE_PATH" || RC=$?

    case "$RC" in
    0 | 2) ;;
    *)
      exit 2
      ;;
    esac
  fi
  ;;
*.md)
  if command -v -- prettier > /dev/null; then
    markdown-fmt --tabsize=2 --filename _.md < "$FILE_PATH" | sponge -- "$FILE_PATH" || exit 2
  fi
  ;;
# *.lua)
#   stylua --syntax=LuaJit --indent-type=Spaces --indent-width=2 --sort-requires --call-parentheses=None -- "$FILE_PATH" || exit 2
#   ;;
*)
  exit 0
  ;;
esac >&2
