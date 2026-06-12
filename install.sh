#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
# -n(-h): 대상이 기존 심볼릭 링크여도 따라가지 않고 링크 자체를 교체한다 (멱등 — 재실행 시
# 링크를 따라 들어가 디렉토리 안에 자기참조 심링크를 만드는 ln -sf의 함정 방지)
ln -sfn "$DIR/harness-scaffold" "$HOME/.claude/skills/harness-scaffold"
echo "✓ harness-scaffold 심볼릭 링크 생성 완료"
echo "  $HOME/.claude/skills/harness-scaffold → $DIR/harness-scaffold"
ln -sfn "$DIR/companion-skills/multi-model-consult" "$HOME/.claude/skills/multi-model-consult"
echo "✓ multi-model-consult 심볼릭 링크 생성 완료 (범용 멀티모델 자문 — 하네스 비의존)"
echo "  $HOME/.claude/skills/multi-model-consult → $DIR/companion-skills/multi-model-consult"
