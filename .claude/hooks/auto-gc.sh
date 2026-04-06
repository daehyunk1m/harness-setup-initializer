#!/bin/bash
# Stop hook: 미커밋 변경이 있으면 stop을 블록하고 /gc + push 실행을 지시
# 무한루프 방지: 60초 내 재블록하지 않음

GUARD="/tmp/claude-gc-stop"

changes=$(git status --porcelain 2>/dev/null)

# 변경 없음 → push 후 통과
if [ -z "$changes" ]; then
  rm -f "$GUARD"
  # 원격에 push 안 된 커밋이 있으면 push
  ahead=$(git rev-list --count HEAD...@{u} --left-only 2>/dev/null || echo "0")
  if [ "$ahead" -gt 0 ]; then
    echo "{\"continue\":false,\"stopReason\":\"원격에 push되지 않은 커밋이 ${ahead}개 있습니다. /gs push를 실행하세요.\"}"
  else
    echo '{}'
  fi
  exit 0
fi

# 60초 내 이미 블록한 적 있음 → 통과 (무한루프 방지)
if [ -f "$GUARD" ]; then
  age=$(($(date +%s) - $(stat -f %m "$GUARD")))
  if [ "$age" -lt 60 ]; then
    rm -f "$GUARD"
    echo '{}'
    exit 0
  fi
fi

# 미커밋 변경 감지 → stop 블록
touch "$GUARD"
echo '{"continue":false,"stopReason":"미커밋 변경사항이 감지되었습니다. /gc를 실행하여 커밋한 뒤 /gs push로 원격에 반영하세요."}'
