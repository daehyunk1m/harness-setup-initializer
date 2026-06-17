#!/usr/bin/env bash
# Intent→PRD Coverage 골든 픽스처 — Phase 2b-2
# 검증(결정적 기계만 — LLM 의미판정 제외): (1) 백로그 2차원 헤더, (2) PRD 바인딩 grep, (3) 섹션 추출기/빈섹션 가드
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BL="$ROOT/skills/harness-scaffold/templates/INTENT_BACKLOG.md"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

prd_section_body() {
  awk -v sec="$1" '
    /<!--[[:space:]]*harness:section=/ { insec = ($0 ~ ("harness:section=" sec "[[:space:]]")); next }
    !insec { next }
    { l=$0; sub(/^[[:space:]]+/,"",l); sub(/[[:space:]]+$/,"",l) }
    incmt { if (l ~ /-->/) incmt=0; next }
    l ~ /^<!--/ && l !~ /-->/ { incmt=1; next }
    l ~ /^<!--.*-->$/ { next }
    l ~ /^#/ { next }
    l == "" { next }
    { print l }
  ' "$2"
}

echo "T1: 백로그 2차원 헤더"
{ grep -q "prd_state" "$BL" 2>/dev/null && ok "prd_state 컬럼"; } || no "prd_state 컬럼 없음"
{ grep -q "e2e_state" "$BL" 2>/dev/null && ok "e2e_state 컬럼"; } || no "e2e_state 컬럼 없음"
{ ! grep -qE '\| *state *\|' "$BL" 2>/dev/null && ok "구 단일 state 컬럼 제거"; } || no "구 state 컬럼 잔존"
{ grep -q "priority/비고" "$BL" 2>/dev/null && ok "priority/비고 사용자 컬럼"; } || no "priority/비고 없음"
{ grep -q "derived" "$BL" 2>/dev/null && ok "derived/user 분리 노트"; } || no "derived 노트 없음"

echo "T2: PRD 바인딩 grep (whole-line -Fx)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/docs/product-specs"
printf '@feature:F007\n\n# Progress\n' > "$TMP/docs/product-specs/F007-progress.md"
printf '# Note\n\n`@feature:F007` 참고\n' > "$TMP/docs/product-specs/inline.md"
M="$(cd "$TMP" && grep -Rl -Fx "@feature:F007" docs/product-specs/ 2>/dev/null)"
{ echo "$M" | grep -q "F007-progress.md" && ok "바인딩 PRD 발견"; } || no "바인딩 PRD 미발견"
{ echo "$M" | grep -q "inline.md" && no "본문 인라인 오탐"; } || ok "본문 인라인 기각"
{ (cd "$TMP" && grep -Rl -Fx "@feature:F999" docs/product-specs/ 2>/dev/null | grep -q .) && no "미존재 feature 오매칭"; } || ok "feature-without-PRD 감지(missing 후보)"

echo "T3: 섹션 추출기 / 빈섹션 가드"
FILLED="$TMP/filled.md"; EMPTY="$TMP/empty.md"
cat > "$FILLED" <<'MD'
@feature:F007
<!-- harness:section=edge-cases -->
## ⚠️ Edge Cases
someday 항목은 집계에서 제외한다
MD
cat > "$EMPTY" <<'MD'
@feature:F008
<!-- harness:section=edge-cases -->
## ⚠️ Edge Cases
<!-- [필수] 제외 조건을 명시한다.
     빈칸으로 두지 않는다. -->
<!-- harness:section=acceptance -->
## Acceptance
MD
{ [ -n "$(prd_section_body edge-cases "$FILLED")" ] && ok "채워진 섹션→본문 있음"; } || no "채워진 섹션 본문 미추출"
{ [ -z "$(prd_section_body edge-cases "$EMPTY")" ] && ok "빈 섹션(헤딩+멀티라인주석)→본문 없음(covered 금지)"; } || no "빈 섹션 오추출(false-covered 위험)"

echo
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "✅ 전부 통과"; exit 0; } || { echo "❌ 실패 있음"; exit 1; }
