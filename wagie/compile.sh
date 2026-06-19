#!/usr/bin/env -S -- bash -Eeu -o pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

OUT="$1"
CLAUDE_CONFIG_DIR="$OUT/.claude"
SELF="${0%/*}"

mkdir -v -p -- "$CLAUDE_CONFIG_DIR"
cp -af -- "$SELF/../opt/claude-code"/{agents,bin,hooks,libexec,rules,skills,AGENTS.md,keybindings.json} "$CLAUDE_CONFIG_DIR/"
mv -- "$CLAUDE_CONFIG_DIR/AGENTS.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"

rm -fr -- "$CLAUDE_CONFIG_DIR/skills/shitpost" "$CLAUDE_CONFIG_DIR/agents/web-research.md"

LAYERS=(
  agents.d
  hooks.d
  rules.d
  skills.d
)

for LAYER in "${LAYERS[@]}"; do
  SRC=$OUT/$LAYER
  if [[ -d $SRC ]]; then
    rsync --archive --keep-dirlinks -- "$SRC" "$CLAUDE_CONFIG_DIR/"
  fi
done
