#!/bin/bash
#
# harness-setup 마이그레이션 스크립트
#
# 배포 방식이 "git clone + 심볼릭 링크"에서 Claude Code **플러그인**으로 전환되었다 (1.23.0).
# 이 스크립트는 더 이상 스킬을 설치하지 않는다. 대신:
#   (1) 이전 install.sh가 만든 구 심볼릭 링크를 정리하고 (심링크일 때만 — 데이터 보호)
#   (2) 플러그인 설치 방법을 안내한다.
#
# 멱등 — 재실행해도 안전하다.
set -e
SKILLS_DIR="$HOME/.claude/skills"

echo "harness-setup 배포 방식이 Claude Code 플러그인으로 전환되었습니다 (1.23.0)."
echo ""

# 1. 구 심볼릭 링크 정리 — 반드시 심볼릭 링크일 때만 제거한다.
#    실제 디렉토리(사용자 데이터/클론)는 절대 삭제하지 않는다 (-L 가드).
removed=0
for name in harness-scaffold harness-cleanup harness-feedback multi-model-consult; do
  link="$SKILLS_DIR/$name"
  if [ -L "$link" ]; then
    rm -f "$link"
    echo "  ✓ 구 심볼릭 링크 제거: $link"
    removed=$((removed + 1))
  fi
done
if [ "$removed" -eq 0 ]; then
  echo "  (정리할 구 심볼릭 링크 없음)"
fi
echo ""

# 2. 플러그인 설치 안내
cat <<'EOF'
다음 명령으로 플러그인을 설치하세요 (Claude Code 세션에서 입력):

  /plugin marketplace add daehyunk1m/harness-setup-initializer
  /plugin install harness-setup@harness-setup-initializer
  /reload-plugins

설치하면 5개 스킬이 함께 로드됩니다:
  harness-setup · harness-scaffold · harness-cleanup · harness-feedback · multi-model-consult

참고:
  - git clone + git pull로는 더 이상 스킬이 갱신되지 않습니다.
  - 이 클론은 플러그인 소스/개발용으로만 사용하세요. ~/.claude/skills/ 안에 두면
    플러그인 설치본과 중복 발견될 수 있으니, 개발 클론은 ~/.claude/skills/ 밖으로
    옮기는 것을 권장합니다.
EOF
