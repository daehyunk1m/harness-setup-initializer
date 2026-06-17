#!/usr/bin/env bash
# PRD substrate 골든 픽스처 — Phase 2b-1
# 검증: (1) _template.md 구조, (2) README.md 구조, (3) whole-line @feature 마커 grep 규칙
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL_DIR="$ROOT/skills/harness-scaffold/templates/product-specs"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "T1: _template.md 구조"
T="$TPL_DIR/_template.md"
{ [ -f "$T" ] && ok "_template.md 존재"; } || no "_template.md 없음"
{ grep -Fxq "@feature:F000" "$T" 2>/dev/null && ok "@feature:F000 마커 (whole-line)"; } || no "@feature:F000 whole-line 마커 없음"
for a in intent behavior edge-cases acceptance open-questions; do
  { grep -q "harness:section=$a" "$T" 2>/dev/null && ok "섹션 앵커 $a"; } || no "섹션 앵커 $a 없음"
done
{ grep -q "빈칸" "$T" 2>/dev/null && ok "Edge Cases anti-blank 가이드"; } || no "anti-blank 가이드 없음"
{ grep -q "{{" "$T" 2>/dev/null && no "플레이스홀더 잔존({{)"; } || ok "플레이스홀더 0"

echo "T2: README.md 구조"
R="$TPL_DIR/README.md"
{ [ -f "$R" ] && ok "README.md 존재"; } || no "README.md 없음"
{ grep -q "{featureID}-{slug}" "$R" 2>/dev/null && ok "네이밍 관례"; } || no "네이밍 관례 없음"
{ grep -q "grep -Rl -Fx" "$R" 2>/dev/null && ok "마커 grep 규칙"; } || no "마커 grep 규칙 없음"
{ grep -q "{{" "$R" 2>/dev/null && no "플레이스홀더 잔존({{)"; } || ok "플레이스홀더 0"

echo "T3: whole-line @feature 마커 grep 규칙"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/product-specs"
printf '@feature:F007\n\n# Progress\n' > "$TMP/product-specs/F007-progress.md"
printf '@feature:Fcustom.1\n\n# Custom\n' > "$TMP/product-specs/Fcustom.1-x.md"
printf '# Note\n\n`@feature:F007`를 추가하세요\n' > "$TMP/product-specs/inline.md"
M="$(grep -Rl -Fx "@feature:F007" "$TMP/product-specs" 2>/dev/null)"
{ echo "$M" | grep -q "F007-progress.md" && ok "whole-line @feature:F007 매칭"; } || no "whole-line 매칭 실패"
{ echo "$M" | grep -q "inline.md" && no "본문 인라인 오탐 발생"; } || ok "본문 인라인 오탐 기각"
MC="$(grep -Rl -Fx "@feature:Fcustom.1" "$TMP/product-specs" 2>/dev/null)"
{ echo "$MC" | grep -q "Fcustom.1-x.md" && ok "커스텀 ID 리터럴 매칭(-Fx)"; } || no "커스텀 ID 매칭 실패"

echo
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "✅ 전부 통과"; exit 0; } || { echo "❌ 실패 있음"; exit 1; }
