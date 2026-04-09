#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
ln -sf "$DIR/harness-scaffold" "$HOME/.claude/skills/harness-scaffold"
echo "✓ harness-scaffold 심볼릭 링크 생성 완료"
echo "  $HOME/.claude/skills/harness-scaffold → $DIR/harness-scaffold"
