#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OUT="$(realpath --canonicalize-missing -- "$1")"
ROOT="$OUT/.claude"
SELF="$(realpath -- "$0")"
SELF="${SELF%/*}"

mkdir -v -p -- "$ROOT"
cp -af --dereference -- "$SELF/../opt/claude-code"/{bin,hooks,keybindings.json} "$ROOT/"
mkdir -v -p -- "$ROOT/libexec/linters"
cp -af -- "$SELF/../opt/claude-code/libexec"/{notify.sh,otel-headers-helper.sh} "$ROOT/libexec/"
cp -af --dereference -- "$SELF/../opt/claude-code/libexec"/{log-hooks.sh,read-session.sh,session-file.sh,which-session.sh} "$ROOT/libexec/"
env -C "$ROOT/libexec/linters" -- rsync --archive --copy-links --exclude='/markdown/' -- "$SELF/../opt/codex/libexec/linters/" .
cp -af -- "$SELF/../opt/codex/libexec/worktree" "$ROOT/libexec/"
cp -af --dereference -- "$SELF/../opt/codex"/{agents,rules,skills,AGENTS.md} "$ROOT/"
if [[ -f $ROOT/AGENTS.md ]]; then
  mv -- "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md"
fi

rm -fr -- "$ROOT/skills/shitpost" "$ROOT/agents/web-research.md"

mkdir -v -p -- "$OUT/opt"
cp -af --dereference -- "$SELF/../opt/mcp/." "$OUT/opt/mcp/"

LAYERS=(
  agents.d
  hooks.d
  rules.d
  skills.d
)

for LAYER in "${LAYERS[@]}"; do
  SRC=$OUT/$LAYER
  if [[ -d $SRC ]]; then
    mkdir -p -- "$ROOT/$LAYER"
    env -C "$ROOT/$LAYER" -- rsync --archive --copy-links --keep-dirlinks -- "$SRC/" .
  fi
done

find "$ROOT" -type f -name '*.md' -exec sed -i -e 's/AGENTS\.md/CLAUDE.md/g' {} +
