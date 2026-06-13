#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.claude/skills"

# -n(-h): 대상이 기존 심볼릭 링크여도 따라가지 않고 링크 자체를 교체한다 (멱등 — 재실행 시
# 링크를 따라 들어가 디렉토리 안에 자기참조 심링크를 만드는 ln -sf의 함정 방지)
ln -sfn "$DIR/harness-scaffold" "$HOME/.claude/skills/harness-scaffold"
echo "✓ harness-scaffold 심볼릭 링크 생성 완료"

# 모든 컴패니언 스킬을 글로벌 디스커버리 대상으로 링크한다 (Issue #8)
# — feedback/cleanup은 하네스 셋업 프로젝트에서, multi-model-consult는 범용.
#   생성된 CLAUDE.md의 "하네스 피드백 분석해줘" 등 안내가 실제 디스커버리와 일치하도록.
for skill_dir in "$DIR/companion-skills"/*/; do
  name="$(basename "$skill_dir")"
  [ -f "$skill_dir/SKILL.md" ] || continue   # SKILL.md 없는 디렉토리는 스킵
  ln -sfn "${skill_dir%/}" "$HOME/.claude/skills/$name"
  echo "✓ $name 심볼릭 링크 생성 완료 (companion)"
done

echo "  → $HOME/.claude/skills/ 에 scaffold + companion 스킬이 링크되었습니다."
