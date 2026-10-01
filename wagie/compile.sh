#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OUT="$(realpath --canonicalize-missing -- "$1")"
ROOT="$OUT/.claude"
SELF="$(realpath -- "$0")"
OPT="${SELF%/*}/../opt"

RSYNC=(rsync --archive --copy-links)
DIRS=("$ROOT/libexec/linters" "$OUT/opt")
LAYERS=(agents.d hooks.d rules.d skills.d)
for LAYER in "${LAYERS[@]}"; do
  DIRS+=("$OUT/$LAYER" "$ROOT/$LAYER")
done

mkdir -v -p -- "${DIRS[@]}"
{
  cp -af --dereference -- "$OPT/claude-code"/{bin,hooks,keybindings.json} "$ROOT/"
  cp -af --dereference -- "$OPT/claude-code/libexec"/{log-hooks.sh,instruction-delta.sh,s6} "$ROOT/libexec/"
  cp -af --dereference -- "$OPT/codex"/{agents,rules,skills,AGENTS.md} "$ROOT/"
  cp -af --dereference -- "$OPT/mcp/." "$OUT/opt/mcp/"
  cp -af -- "$OPT/claude-code/libexec"/{notify.sh,otel-headers-helper.sh} "$ROOT/libexec/"
  cp -af -- "$OPT/codex/libexec/worktree" "$ROOT/libexec/"
  env -C "$ROOT/libexec/linters" -- "${RSYNC[@]}" --exclude='/markdown/' -- "$OPT/codex/libexec/linters/" .
  mv -- "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md"
  rm -fr -- "$ROOT/skills/shitpost" "$ROOT/agents/web-research.md"
}

for LAYER in "${LAYERS[@]}"; do
  env -C "$ROOT/$LAYER" -- "${RSYNC[@]}" --keep-dirlinks -- "$OUT/$LAYER/" .
done

find "$ROOT" -type f -name '*.md' -exec sed -i -e 's/AGENTS\.md/CLAUDE.md/g' {} +
