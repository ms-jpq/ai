#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

if ! [[ -v RECUR ]]; then
  JSON="$(tee)"
  # "${0%/*}/../libexec/log-hooks.sh" "$0" <<< "$JSON"
  read -r -d '' -- JQ <<- 'JQ' || true
.tool_calls[]? | select(.tool_name | IN("Write", "Edit", "MultiEdit")) | .tool_input.file_path
JQ

  CTX="$(jq --raw-output0 "$JQ" <<< "$JSON" | sort -z --unique | RECUR=1 xargs -r --null -I % --max-procs=0 -- "$0" % 2>&1 || true)"
  read -r -d '' -- JQ <<- 'JQ' || true
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolBatch",
    "additionalContext": $context
  }
}
JQ

  exec -- jq -e --null-input --arg context "$CTX" "$JQ"
fi

FILE_PATH="$*"
case "$FILE_PATH" in
*.awk)
  awk-fmt < "$FILE_PATH" | sponge -- "$FILE_PATH"
  ;;
*.link | *.netdev | *.network | *.socket | *.service | *.target | *.mount | *.automount | *.dnssd | */repart.d/*.conf | */systemd/**/*.conf | */*.network.d/*.conf)
  systemd-fmt.sh "$FILE_PATH" > /dev/null
  ;;
*.json)
  jq --sort-keys -- . < "$FILE_PATH" | sponge -- "$FILE_PATH"
  if command -v -- prettier > /dev/null; then
    prettier --log-level=warn --write -- "$FILE_PATH"
  fi
  ;;
*.jsonl)
  jq --sort-keys --compact-output -- . < "$FILE_PATH" | sponge -- "$FILE_PATH"
  ;;
*.toml)
  if command -v -- taplo > /dev/null; then
    RUST_LOG=warn taplo format -- "$FILE_PATH"
  fi
  ;;
*.sh | *.bash)
  if command -v -- shfmt > /dev/null; then
    shfmt --simplify --binary-next-line --space-redirects --indent=2 --write -- "$FILE_PATH"
  fi
  if command -v -- shellcheck > /dev/null; then
    shellcheck --shell=bash -- "$FILE_PATH"
  fi
  ;;
*Dockerfile | *Dockerfile.* | *.dockerfile | *Containerfile)
  if command -v -- hadolint > /dev/null; then
    hadolint -- "$FILE_PATH"
  fi
  ;;
*.lua)
  if command -v -- stylua > /dev/null; then
    stylua --syntax=LuaJit --indent-type=Spaces --indent-width=2 --sort-requires --call-parentheses=None -- "$FILE_PATH"
  fi
  ;;
*.pl | *.pm | *.t)
  if command -v -- perltidy > /dev/null; then
    CODE=0
    perltidy --standard-error-output --backup-and-modify-in-place --backup-file-extension=/ --indent-columns=2 --output-line-ending=unix -- "$FILE_PATH" || CODE=$?
    case "$CODE" in 0 | 2)
      exit
      ;;
    *)
      exit 1
      ;;
    esac
  fi
  ;;
*.md)
  if command -v -- prettier > /dev/null; then
    markdown-fmt --tabsize=2 --filename _.md < "$FILE_PATH" | sponge -- "$FILE_PATH"
  fi
  ;;
*)
  ;;
esac
