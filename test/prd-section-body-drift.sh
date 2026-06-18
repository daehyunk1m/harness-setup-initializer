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
# 조기-절단 방어 (Inc2 Minor): norm()은 함수경계를 첫 `}`-줄로 잡는데, awk 본문에 단독 `}` 줄이
# 생기면 두 사본이 똑같이 잘려 tail diff를 놓친 채 false-sync가 날 수 있다(들여쓴 SKILL.md
# 사본 때문에 /^}/로 좁힐 수 없음). 본문 종단 awk 액션('print l')이 추출물에 없으면 절단으로 보고 실패.
case "$A" in *"print l"*) : ;; *) echo "❌ harness-check.sh prd_section_body 추출이 조기 절단된 듯 (종단 'print l' 누락) — norm() 함수경계 추출 점검"; exit 1 ;; esac
case "$B" in *"print l"*) : ;; *) echo "❌ intent-distill SKILL.md prd_section_body 추출이 조기 절단된 듯 (종단 'print l' 누락) — norm() 함수경계 추출 점검"; exit 1 ;; esac
if [ "$A" = "$B" ]; then
  echo "✅ prd_section_body 동기 (harness-check ≡ intent-distill SKILL.md)"; exit 0
else
  echo "❌ prd_section_body drift 발견:"; diff <(printf '%s\n' "$A") <(printf '%s\n' "$B"); exit 1
fi
