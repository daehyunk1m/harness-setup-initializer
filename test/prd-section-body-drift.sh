#!/usr/bin/env bash
# prd_section_body drift-guard — Phase 2b-3 Increment 2
# harness-check.sh(canonical 실행 소스)와 intent-distill SKILL.md §4.1 doc 사본의
# prd_section_body awk가 정규화 후 동일한지 단언 (3-way drift 봉쇄).
# coverage 픽스처는 source 전환(Task 3)으로 자동 일치하므로 비교 대상 아님.
# 사용법: bash test/prd-section-body-drift.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/skills/harness-scaffold/templates/harness-check.sh"
SK="$ROOT/skills/intent-distill/SKILL.md"
# 함수 본문만 추출 + 선행/내부/후행 공백 정규화 (들여쓰기 차이 무시 — codex brittle 우려 반영)
norm(){ sed -n '/prd_section_body()/,/^[[:space:]]*}/p' "$1" \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g'; }
A="$(norm "$HC")"; B="$(norm "$SK")"
[ -n "$A" ] || { echo "❌ harness-check.sh에서 prd_section_body 추출 실패"; exit 1; }
[ -n "$B" ] || { echo "❌ intent-distill SKILL.md에서 prd_section_body 추출 실패"; exit 1; }
if [ "$A" = "$B" ]; then
  echo "✅ prd_section_body 동기 (harness-check ≡ intent-distill SKILL.md)"; exit 0
else
  echo "❌ prd_section_body drift 발견:"; diff <(printf '%s\n' "$A") <(printf '%s\n' "$B"); exit 1
fi
