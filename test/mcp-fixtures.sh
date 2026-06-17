#!/bin/bash
# MCP 진단 배선 골든 픽스처 (이슈 #12 증분 3) — 스킬 자체 검증, 생성 프로젝트와 무관(footprint 0)
#
# 검증:
#   1. debugger.md에 {{MCP_DEBUG_PROTOCOL}} 정확히 1개
#   2. 빈 치환(미옵트인) → 잔여 {{}} 0 + §0/§1 구조 유지
#   3. scaffold 치환 규칙에 {{MCP_DEBUG_PROTOCOL}} + 블록 핵심 마커 존재
#   4. 두 SKILL.md에 e2e.mcp 스키마 동기
# 요구: grep. 사용법: bash test/mcp-fixtures.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DBG="$ROOT/skills/harness-scaffold/templates/agents/debugger.md"
SCAFFOLD="$ROOT/skills/harness-scaffold/SKILL.md"
SETUP="$ROOT/skills/harness-setup/SKILL.md"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0
echo "═══ MCP 진단 배선 픽스처 ═══"

# 1. debugger.md에 {{MCP_DEBUG_PROTOCOL}} 정확히 1개
N=$(grep -c '{{MCP_DEBUG_PROTOCOL}}' "$DBG" || true)
if [ "$N" = "1" ]; then echo "✅ debugger.md MCP 플레이스홀더 1개"
else echo "❌ MCP 플레이스홀더 ${N}개(기대 1)"; FAILS=$((FAILS+1)); fi

# 2. 빈 치환(미옵트인) → 잔여 {{}} 0 + §0/§1 구조 유지
sed -e 's#{{MCP_DEBUG_PROTOCOL}}##g' \
    -e 's#{{VALIDATE_COMMAND}}#npm run validate#g' \
    -e 's#{{E2E_COMMAND}}#npm run test:e2e#g' "$DBG" > "$TMP/empty.md"
if grep -q '{{.*}}' "$TMP/empty.md"; then
  echo "❌ 빈 치환 후 잔여 플레이스홀더:"; grep -n '{{.*}}' "$TMP/empty.md"; FAILS=$((FAILS+1))
else echo "✅ 빈 치환 후 잔여 0"; fi
if grep -q '진단 프로토콜' "$TMP/empty.md" && grep -q 'E2E 실패 진단' "$TMP/empty.md"; then
  echo "✅ §0/§1 구조 유지"
else echo "❌ §0/§1 구조 손상"; FAILS=$((FAILS+1)); fi

# 3. scaffold 치환 규칙 + 블록 핵심 마커 (실제 authored 블록 검증)
MISS=0
for m in '{{MCP_DEBUG_PROTOCOL}}' 'claude mcp add playwright-harness' '@playwright/mcp' '--headless' '--isolated' 'localhost' '관찰 로그'; do
  grep -qF -- "$m" "$SCAFFOLD" || { echo "  · scaffold 마커 누락: $m"; MISS=$((MISS+1)); }
done
if [ "$MISS" = "0" ]; then echo "✅ scaffold 치환 규칙 + 블록 마커 존재"
else echo "❌ scaffold 마커 ${MISS}건 누락"; FAILS=$((FAILS+1)); fi

# 4. 두 SKILL.md에 e2e.mcp 스키마 동기
grep -q '"mcp"' "$SETUP"    && echo "✅ SKILL.md e2e.mcp 스키마"  || { echo "❌ SKILL.md e2e.mcp 누락"; FAILS=$((FAILS+1)); }
grep -q '"mcp"' "$SCAFFOLD" && echo "✅ scaffold e2e.mcp 스키마" || { echo "❌ scaffold e2e.mcp 누락"; FAILS=$((FAILS+1)); }

echo ""; echo "═══ 판정 ═══"
if [ "$FAILS" -eq 0 ]; then echo "✅ 전체 통과 — MCP 배선 정합"; exit 0
else echo "❌ ${FAILS}건 실패"; exit 1; fi
