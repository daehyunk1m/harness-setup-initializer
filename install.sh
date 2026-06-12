#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
ln -sf "$DIR/harness-scaffold" "$HOME/.claude/skills/harness-scaffold"
echo "✓ harness-scaffold 심볼릭 링크 생성 완료"
echo "  $HOME/.claude/skills/harness-scaffold → $DIR/harness-scaffold"
ln -sf "$DIR/companion-skills/multi-model-consult" "$HOME/.claude/skills/multi-model-consult"
echo "✓ multi-model-consult 심볼릭 링크 생성 완료 (범용 멀티모델 자문 — 하네스 비의존)"
echo "  $HOME/.claude/skills/multi-model-consult → $DIR/companion-skills/multi-model-consult"
