#!/usr/bin/env bash
# PRD 마커 위생 골든 픽스처 — Phase 2b-3 Increment 1
# 검증: harness-check.sh ⑩의 prd_marker_hygiene 함수를 템플릿에서 추출·source해
#   5종 마커 위반(unbound/multiple/invalid-feature/file-marker-mismatch/duplicate-binding)
#   감지 + 정상 무경고 + substrate/PRD 부재 보류 + render-after 와이어링(exit 0)을 확인한다.
# 사용법: bash test/prd-marker-hygiene-fixtures.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/skills/harness-scaffold/templates/harness-check.sh"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# 템플릿에서 함수 블록을 추출·source (단일 소스 — 로직 복사 없음)
FN="$(mktemp)"; trap 'rm -f "$FN"' EXIT
sed -n '/# --- harness:prd-marker-hygiene:start/,/# --- harness:prd-marker-hygiene:end/p' "$HC" > "$FN"
if ! grep -q 'prd_marker_hygiene()' "$FN"; then
  echo "❌ 템플릿에서 prd_marker_hygiene 함수 추출 실패 (추출 마커/함수 정의 확인)"
  exit 1
fi
# shellcheck disable=SC1090
. "$FN"

# 헬퍼: 임시 프로젝트 디렉토리에서 함수 실행 → stdout 캡처
run_in(){ ( cd "$1" && prd_marker_hygiene ); }
mkproj(){ # $1=dir; substrate + 주어진 feature_list ids
  mkdir -p "$1/docs/product-specs"
  printf '# README\n' > "$1/docs/product-specs/README.md"
  printf '@feature:F000\n# T\n' > "$1/docs/product-specs/_template.md"
  printf '%s' "$2" > "$1/feature_list.json"
}

TMP="$(mktemp -d)"; trap 'rm -f "$FN"; rm -rf "$TMP"' EXIT
FL='[{"id":"F001"},{"id":"F002"},{"id":"F-infra-0"}]'

echo "T1: 정상 PRD (마커 1·유효 id·파일명 일치) → 무경고"
D="$TMP/t1"; mkproj "$D" "$FL"; printf '@feature:F001\n# P\n' > "$D/docs/product-specs/F001-progress.md"
OUT="$(run_in "$D")"
{ echo "$OUT" | grep -q "✅ PRD 마커 위생 정상" && ! echo "$OUT" | grep -q "⚠️"; } && ok "정상 무경고" || no "정상인데 경고 발생: $OUT"

echo "T2: unbound-prd (마커 0)"
D="$TMP/t2"; mkproj "$D" "$FL"; printf '# 마커 없음\n본문\n' > "$D/docs/product-specs/F001-x.md"
echo "$(run_in "$D")" | grep -q "⚠️ unbound-prd: F001-x.md" && ok "unbound 감지" || no "unbound 미감지"

echo "T3: multiple-markers (마커 2)"
D="$TMP/t3"; mkproj "$D" "$FL"; printf '@feature:F001\n@feature:F002\n# P\n' > "$D/docs/product-specs/F001-x.md"
echo "$(run_in "$D")" | grep -q "⚠️ multiple-markers: F001-x.md" && ok "multiple 감지" || no "multiple 미감지"

echo "T4: invalid-feature (마커 id ∉ feature_list)"
D="$TMP/t4"; mkproj "$D" "$FL"; printf '@feature:F999\n# P\n' > "$D/docs/product-specs/F999-x.md"
echo "$(run_in "$D")" | grep -q "⚠️ invalid-feature: F999-x.md" && ok "invalid 감지" || no "invalid 미감지"

echo "T5: file-marker-mismatch (파일명 F001-, 마커 F002)"
D="$TMP/t5"; mkproj "$D" "$FL"; printf '@feature:F002\n# P\n' > "$D/docs/product-specs/F001-x.md"
echo "$(run_in "$D")" | grep -q "⚠️ file-marker-mismatch: F001-x.md" && ok "mismatch 감지" || no "mismatch 미감지"

echo "T6: duplicate-binding (두 PRD 같은 id)"
D="$TMP/t6"; mkproj "$D" "$FL"
printf '@feature:F001\n# A\n' > "$D/docs/product-specs/F001-a.md"
printf '@feature:F001\n# B\n' > "$D/docs/product-specs/F001-b.md"
echo "$(run_in "$D")" | grep -q "⚠️ duplicate-binding: feature F001" && ok "duplicate 감지" || no "duplicate 미감지"

echo "T7: 하이픈 id 안전 (파일명 F-infra-0-x, 마커 F-infra-0) → 일치 무경고"
D="$TMP/t7"; mkproj "$D" "$FL"; printf '@feature:F-infra-0\n# P\n' > "$D/docs/product-specs/F-infra-0-wiring.md"
OUT="$(run_in "$D")"
{ ! echo "$OUT" | grep -q "⚠️"; } && ok "하이픈 id 일치 무경고" || no "하이픈 id 오탐: $OUT"

echo "T8: slug-only 파일명 (progress-chart.md, 마커 유효) → mismatch 침묵"
D="$TMP/t8"; mkproj "$D" "$FL"; printf '@feature:F001\n# P\n' > "$D/docs/product-specs/progress-chart.md"
OUT="$(run_in "$D")"
{ ! echo "$OUT" | grep -q "file-marker-mismatch" && ! echo "$OUT" | grep -q "⚠️"; } && ok "slug-only 침묵(경고 0)" || no "slug-only 오탐: $OUT"

echo "T9: substrate 부재 → 보류"
D="$TMP/t9"; mkdir -p "$D"; printf '%s' "$FL" > "$D/feature_list.json"
echo "$(run_in "$D")" | grep -q "⏸️ product-specs substrate 부재" && ok "substrate 부재 보류" || no "substrate 부재 보류 미동작"

echo "T10: 작성 PRD 0개 → 보류"
D="$TMP/t10"; mkproj "$D" "$FL"
echo "$(run_in "$D")" | grep -q "⏸️ 작성된 PRD 없음" && ok "PRD 0개 보류" || no "PRD 0개 보류 미동작"

echo "T11: README/_template의 @feature:F000 → 검사 제외 (경고 0)"
D="$TMP/t11"; mkproj "$D" "$FL"; printf '@feature:F001\n# P\n' > "$D/docs/product-specs/F001-ok.md"
OUT="$(run_in "$D")"
{ ! echo "$OUT" | grep -qE "F000|_template|README" && ! echo "$OUT" | grep -q "⚠️"; } && ok "substrate 파일 검사 제외(경고 0)" || no "substrate 파일 오탐: $OUT"

echo "T12: render-after 와이어링 (전체 스크립트 exit 0 + ⑩ 출력)"
D="$TMP/t12"; mkproj "$D" "$FL"; printf '@feature:F001\n# P\n' > "$D/docs/product-specs/F001-ok.md"
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt .harness-friction.jsonl .harness-intent.jsonl init.sh; do printf '# x\n' > "$D/$f"; done
mkdir -p "$D/scripts"; printf '// st\n' > "$D/scripts/structural-test.ts"; printf '// df\n' > "$D/scripts/doc-freshness.ts"
# 플레이스홀더를 no-op으로 치환 (package.json 부재 → DEPS_MISSING=0 → ④⑤ 실행)
sed -e 's#{{LINT_ARCH_COMMAND}}#true#g' -e 's#{{VALIDATE_COMMAND}}#true#g' \
    -e 's#{{DOC_CHECK_COMMAND}}#true#g' -e 's#{{PATH_ALIAS_LIST}}##g' "$HC" > "$D/hc.sh"
( cd "$D" && bash hc.sh > out.txt 2>&1 ); CODE=$?
{ [ "$CODE" -eq 0 ] && grep -q "⑩ PRD 위생" "$D/out.txt" && grep -q "✅ PRD 마커 위생 정상" "$D/out.txt"; } \
  && ok "전체 실행 exit 0 + ⑩ 출력 + 정상 판정" || no "render-after 실패 (exit $CODE): $(cat "$D/out.txt")"

echo "T13: feature_list 비어있음([]) + 유효형 마커 → invalid-feature/mismatch 보류 (오탐 방지)"
D="$TMP/t13"; mkproj "$D" "[]"; printf '@feature:F001\n# P\n' > "$D/docs/product-specs/F001-x.md"
OUT="$(run_in "$D")"
{ ! echo "$OUT" | grep -q "⚠️ invalid-feature:" && ! echo "$OUT" | grep -q "⚠️ file-marker-mismatch:"; } && ok "빈 feature_list invalid/mismatch 보류" || no "빈 feature_list 오탐: $OUT"

echo "T14: feature_list 비어있음([]) + 마커 없는 PRD → unbound는 계속 검출"
D="$TMP/t14"; mkproj "$D" "[]"; printf '# 마커 없음\n' > "$D/docs/product-specs/F001-y.md"
echo "$(run_in "$D")" | grep -q "⚠️ unbound-prd: F001-y.md" && ok "빈 feature_list에도 unbound 검출" || no "unbound 미검출"

echo
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "✅ 전부 통과"; exit 0; } || { echo "❌ 실패 있음"; exit 1; }
