#!/bin/bash
set -e

echo "=== 환경 초기화 ==="

# 1. 패키지 매니저 감지 (lockfile 기반)
if [ -f "pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "yarn.lock" ]; then
  PM="yarn"
else
  PM="npm"
fi

# 2. 의존성 설치 (node_modules 없을 때만)
if [ ! -d "node_modules" ]; then
  echo "의존성 설치 중... ($PM install)"
  $PM install
fi

# 3. 개발 서버 실행 (백그라운드)
echo "개발 서버 시작..."
{{DEV_SERVER_COMMAND}} &
DEV_PID=$!

# 4. 서버 준비 대기
echo "서버 준비 대기 중..."
for i in $(seq 1 30); do
  if {{READY_CHECK_COMMAND}} 2>/dev/null | grep -q "200"; then
    echo "✅ 서버 정상 동작 (http://localhost:{{DEV_SERVER_PORT}})"
    break
  fi
  sleep 1
done

if [ "$i" -eq 30 ]; then
  echo "⚠️ 30초 내 서버 응답 없음 — 수동 확인 필요"
fi

echo "=== 초기화 완료 (PID: $DEV_PID) ==="
