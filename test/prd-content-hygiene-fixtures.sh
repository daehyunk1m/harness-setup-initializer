#!/usr/bin/env bash
# PRD 내용 위생(빈 edge-cases 섹션) 골든 픽스처 — Phase 2b-3 Increment 2
# 검증: harness-check.sh의 prd_section_body + prd_content_hygiene을 추출·source해
#   빈 섹션 검출 + placeholder 필터 + 앵커 게이트 + 보류 + render-after(exit 0)를 확인한다.
# 사용법: bash test/prd-content-hygiene-fixtures.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/skills/harness-scaffold/templates/harness-check.sh"
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
no(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# 템플릿에서 두 함수 블록 추출·source (단일 소스 — 로직 복사 없음)
FN="$(mktemp)"
sed -n '/# --- harness:prd-section-body:start/,/# --- harness:prd-section-body:end/p' "$HC" > "$FN"
sed -n '/# --- harness:prd-content-hygiene:start/,/# --- harness:prd-content-hygiene:end/p' "$HC" >> "$FN"
if ! grep -q 'prd_content_hygiene()' "$FN" || ! grep -q 'prd_section_body()' "$FN"; then
  echo "❌ 템플릿에서 함수 추출 실패 (추출 마커/함수 정의 확인)"; rm -f "$FN"; exit 1
fi
# shellcheck disable=SC1090
. "$FN"

TMP="$(mktemp -d)"; trap 'rm -f "$FN"; rm -rf "$TMP"' EXIT
run_in(){ ( cd "$1" && prd_content_hygiene ); }
mkproj(){ mkdir -p "$1/docs/product-specs"
  printf '# README\n' > "$1/docs/product-specs/README.md"
  printf '@feature:F000\n<!-- harness:section=edge-cases -->\n# T\n' > "$1/docs/product-specs/_template.md"; }
# edge-cases 앵커 + 본문 조립 헬퍼
prd(){ printf '@feature:F001\n<!-- harness:section=edge-cases -->\n## ⚠️ Edge Cases\n%b<!-- harness:section=acceptance -->\n## Acceptance\n본문\n' "$2" > "$1"; }

echo "C1: 정상(이유-동반 문장) → 무경고"
D="$TMP/c1"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" 'someday 항목은 집계에서 제외한다\n'
OUT="$(run_in "$D")"; { echo "$OUT" | grep -q "✅ PRD 내용 위생 정상" && ! echo "$OUT" | grep -q "⚠️"; } && ok "정상 무경고" || no "정상인데 경고: $OUT"

echo "C2: 헤딩만(빈 본문) → 경고"
D="$TMP/c2"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" ''
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "헤딩만 검출" || no "헤딩만 미검출"

echo "C3: 공백만 → 경고"
D="$TMP/c3"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '   \n\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "공백만 검출" || no "공백만 미검출"

echo "C4: 주석만(단일+멀티라인) → 경고"
D="$TMP/c4"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '<!-- 한 줄 -->\n<!--\n여러 줄 안내\n-->\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "주석만 검출" || no "주석만 미검출"

echo "C5: bare TBD → 경고"
D="$TMP/c5"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" 'TBD\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "TBD 검출" || no "TBD 미검출"

echo "C6: bare N/A (리스트마커 동반) → 경고"
D="$TMP/c6"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '- N/A\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "N/A 검출" || no "N/A 미검출"

echo "C7: bare 없음 → 경고"
D="$TMP/c7"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '없음\n'
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "없음 검출" || no "없음 미검출"

echo "C8: '명시적 제외 사항 없음'(문장) → 침묵"
D="$TMP/c8"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '명시적 제외 사항 없음\n'
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "문장형 침묵" || no "문장형 오탐: $OUT"

echo "C9: '없음 — someday 제외'(이유 동반) → 침묵"
D="$TMP/c9"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '없음 — someday 태스크는 제외\n'
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "이유동반 침묵" || no "이유동반 오탐: $OUT"

echo "C10: edge-cases 앵커 부재 → 침묵(게이트)"
D="$TMP/c10"; mkproj "$D"; printf '@feature:F001\n# 앵커 없음\n본문\n' > "$D/docs/product-specs/F001-a.md"
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "앵커 부재 침묵" || no "앵커 부재 오탐: $OUT"

echo "C11: 코드펜스 예시만(펜스 구분선 존재) → 침묵"
D="$TMP/c11"; mkproj "$D"; prd "$D/docs/product-specs/F001-a.md" '```html\n<!-- example -->\n```\n'
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "코드펜스 침묵" || no "코드펜스 오탐: $OUT"

echo "C12: CRLF 빈 edge-cases → 경고"
D="$TMP/c12"; mkproj "$D"; printf '@feature:F001\r\n<!-- harness:section=edge-cases -->\r\n## Edge\r\n   \r\n<!-- harness:section=acceptance -->\r\n## A\r\n본문\r\n' > "$D/docs/product-specs/F001-a.md"
echo "$(run_in "$D")" | grep -q "⚠️ empty-edge-cases: F001-a.md" && ok "CRLF 빈 검출" || no "CRLF 빈 미검출"

echo "C13: substrate 부재 → 보류"
D="$TMP/c13"; mkdir -p "$D"
echo "$(run_in "$D")" | grep -q "⏸️ product-specs substrate 부재" && ok "substrate 부재 보류" || no "substrate 보류 미동작"

echo "C14: 작성 PRD 0개 → 보류"
D="$TMP/c14"; mkproj "$D"
echo "$(run_in "$D")" | grep -q "⏸️ 작성된 PRD 없음" && ok "PRD 0개 보류" || no "PRD 0개 보류 미동작"

echo "C15: README/_template은 검사 제외 (경고 0)"
D="$TMP/c15"; mkproj "$D"; prd "$D/docs/product-specs/F001-ok.md" '실제 제외 규칙 명시\n'
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -qE "_template|README" && ! echo "$OUT" | grep -q "⚠️"; } && ok "substrate 파일 제외(경고 0)" || no "substrate 파일 오탐: $OUT"

echo "C16: render-after 와이어링 (전체 스크립트 exit 0 + ⑩ 내용 위생 출력)"
D="$TMP/c16"; mkproj "$D"; prd "$D/docs/product-specs/F001-ok.md" '실제 제외 규칙 명시\n'
printf '[{"id":"F001"}]' > "$D/feature_list.json"
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt .harness-friction.jsonl .harness-intent.jsonl init.sh; do printf '# x\n' > "$D/$f"; done
mkdir -p "$D/scripts"; printf '// st\n' > "$D/scripts/structural-test.ts"; printf '// df\n' > "$D/scripts/doc-freshness.ts"
sed -e 's#{{LINT_ARCH_COMMAND}}#true#g' -e 's#{{VALIDATE_COMMAND}}#true#g' \
    -e 's#{{DOC_CHECK_COMMAND}}#true#g' -e 's#{{PATH_ALIAS_LIST}}##g' "$HC" > "$D/hc.sh"
( cd "$D" && bash hc.sh > out.txt 2>&1 ); CODE=$?
{ [ "$CODE" -eq 0 ] && grep -q "⑩ PRD 위생" "$D/out.txt" && grep -q "✅ PRD 내용 위생 정상" "$D/out.txt"; } \
  && ok "전체 실행 exit 0 + ⑩ 내용 위생 출력" || no "render-after 실패 (exit $CODE): $(cat "$D/out.txt")"

echo "C17: 공백없는 앵커(edge-cases-->) + 내용 → 침묵 (게이트↔awk 정합, false-positive 방지)"
D="$TMP/c17"; mkproj "$D"
printf '@feature:F001\n<!-- harness:section=edge-cases-->\n## Edge\n실제 제외 규칙 명시\n<!-- harness:section=acceptance -->\n## A\n본문\n' > "$D/docs/product-specs/F001-a.md"
OUT="$(run_in "$D")"; { ! echo "$OUT" | grep -q "⚠️"; } && ok "공백없는 앵커 침묵(false-positive 방지)" || no "공백없는 앵커 오탐: $OUT"

echo
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "✅ 전부 통과"; exit 0; } || { echo "❌ 실패 있음"; exit 1; }
