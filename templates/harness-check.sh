#!/bin/bash
# 하네스 자가진단 — 판정 기준: 하네스 구성 체크리스트 § 8 (harness-setup 스킬)
# 사용법: npm run harness:check
# exit 0 = 표준 하네스 가동, exit 1 = 점검 실패 (아래 ❌ 항목 참조)
#
# 항목 구분:
#   하네스 구조 (①②③) — 실패 시 하네스 자체가 깨진 상태
#   프로젝트 품질 (④⑤) — 실패 시 하네스는 정상이나 코드 검증이 깨진 상태
#   경고 전용 (⑥⑦⑧⑨) — exit code에 영향 없음

STRUCT_FAIL=0
QUALITY_FAIL=0
Q2_UNENFORCED=0

echo "═══ 하네스 자가진단 ═══"
echo ""

# ① 필수 파일/디렉토리 존재
echo "── ① 필수 파일 ──"
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt \
         feature_list.json .harness-friction.jsonl init.sh scripts/structural-test.ts scripts/doc-freshness.ts; do
  if [ -f "$f" ]; then
    echo "✅ $f"
  else
    echo "❌ $f 없음"
    STRUCT_FAIL=1
  fi
done
if [ -d docs ]; then
  echo "✅ docs/"
else
  echo "❌ docs/ 없음"
  STRUCT_FAIL=1
fi

# ② AGENTS.md 100줄 이내
echo ""
echo "── ② AGENTS.md 줄수 ──"
if [ -f AGENTS.md ]; then
  LINES=$(wc -l < AGENTS.md | tr -d ' ')
  if [ "$LINES" -le 100 ]; then
    echo "✅ AGENTS.md ${LINES}줄 (≤100)"
  else
    echo "❌ AGENTS.md ${LINES}줄 (>100) — 목차 역할로 압축 필요"
    STRUCT_FAIL=1
  fi
fi

# ③ feature_list.json 유효 JSON
echo ""
echo "── ③ feature_list.json ──"
if node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8'))" 2>/dev/null; then
  echo "✅ feature_list.json 유효한 JSON"
else
  echo "❌ feature_list.json 파싱 실패"
  STRUCT_FAIL=1
fi

# ④ 아키텍처 검증 (exit code 전파)
echo ""
echo "── ④ 아키텍처 검증 ──"
if {{LINT_ARCH_COMMAND}}; then
  echo "✅ 아키텍처 위반 없음"
else
  echo "❌ 아키텍처 검증 실패"
  QUALITY_FAIL=1
fi
# ④-b Q2 강제 여부 — structural-test에 실질 검사 규칙이 있는가 (lint:arch 통과 ≠ 규칙 존재)
if [ -f scripts/structural-test.ts ]; then
  if grep -q "HARNESS:Q2_ENFORCEMENT=unenforced" scripts/structural-test.ts 2>/dev/null; then
    echo "⚠️ Q2 미강제 — structural-test에 기계 검사 규칙 없음 (아키텍처 제약이 문서뿐)"
    Q2_UNENFORCED=1
  elif grep -q "HARNESS:Q2_ENFORCEMENT=enforced" scripts/structural-test.ts 2>/dev/null; then
    echo "✅ Q2 강제 — structural-test 규칙 활성"
  fi
fi

# ⑤ 전체 검증 (exit code 전파)
echo ""
echo "── ⑤ 전체 검증 ──"
if {{VALIDATE_COMMAND}}; then
  echo "✅ validate 통과"
else
  echo "❌ validate 실패"
  QUALITY_FAIL=1
fi

# ⑥ 문서 최신성 (경고만 — doc-freshness는 항상 exit 0)
echo ""
echo "── ⑥ 문서 최신성 ──"
{{DOC_CHECK_COMMAND}} || true

# ⑦ tsconfig paths에 pathAlias 존재 (경고만 — tsconfig는 JSONC라 grep 기반)
echo ""
echo "── ⑦ tsconfig paths ──"
if [ -f tsconfig.json ]; then
  for alias in {{PATH_ALIAS_LIST}}; do
    if grep -q "\"${alias}\*\"" tsconfig.json 2>/dev/null; then
      echo "✅ tsconfig paths: ${alias}*"
    else
      echo "⚠️ tsconfig paths에 ${alias}* 미발견 — pathAlias 설정 확인 권장"
    fi
  done
else
  echo "ℹ️ tsconfig.json 없음 — paths 검사 건너뜀"
fi

# ⑧ E2E 스캐폴드 구조 (경고만 — playwright.config.ts 존재 시에만 검사)
if [ -f playwright.config.ts ]; then
  echo ""
  echo "── ⑧ E2E 스캐폴드 ──"
  if node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts['test:e2e'] ? 0 : 1)" 2>/dev/null; then
    echo "✅ test:e2e 스크립트 존재"
  else
    echo "⚠️ test:e2e 스크립트 미발견 — package.json 확인 권장"
  fi
  if [ -d e2e/specs ]; then
    echo "✅ e2e/specs 디렉토리 존재"
  else
    echo "⚠️ e2e/specs 디렉토리 미발견"
  fi
  # root tsconfig가 e2e를 컴파일에 포함하면 tsc가 e2e를 잘못 컴파일할 수 있음 (tsconfig는 수정하지 않음 — 경고만)
  # JSONC라 grep 기반 soft check: e2e가 이미 exclude되어 있으면(권장 설정) 경고하지 않는다 (오탐 방지)
  if [ -f tsconfig.json ]; then
    if grep -q '"references"' tsconfig.json 2>/dev/null && grep -Eq '"files"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]' tsconfig.json 2>/dev/null; then
      :  # 레퍼런스 위임 루트(files:[]+references) — 자체로 0개 파일 컴파일, e2e는 참조 config + e2e/tsconfig.json로 격리됨 (경고 없음, 오탐 방지)
    elif grep -A3 '"exclude"' tsconfig.json 2>/dev/null | grep -q 'e2e'; then
      :  # e2e가 exclude에 있음 — 정상 (경고 없음)
    elif ! grep -q '"include"' tsconfig.json 2>/dev/null; then
      echo "⚠️ tsconfig.json에 include/exclude 설정 없음 — e2e/가 root 컴파일에 섞일 수 있습니다. root tsconfig exclude에 \"e2e\" 추가 권장 (하네스는 tsconfig를 수정하지 않음)"
    elif grep -A3 '"include"' tsconfig.json 2>/dev/null | grep -q 'e2e'; then
      echo "⚠️ tsconfig.json include가 e2e를 포함하는 듯합니다 — exclude에 \"e2e\" 추가 권장"
    elif grep -A3 '"include"' tsconfig.json 2>/dev/null | grep -Eq '"\*\*|"\*"|"\."'; then
      # 루트 기준 광범위 글롭(["**/*"], ["."], ["*"])은 e2e/까지 컴파일 — 단 "src/**"처럼 경로 접두가 있으면 미해당
      echo "⚠️ tsconfig.json include가 광범위 글롭(\"**\"·\".\" 등)이라 e2e/가 컴파일에 섞일 수 있습니다 — exclude에 \"e2e\" 추가 권장"
    fi
  fi
fi

# ⑨ pre-push 게이트 활성 여부 (경고 전용 — .githooks/pre-push 또는 core.hooksPath 설정 시에만)
HOOKS_PATH=$(git config --get core.hooksPath 2>/dev/null)
if [ -f .githooks/pre-push ] || [ -n "${HOOKS_PATH:-}" ]; then
  echo ""
  echo "── ⑨ pre-push 게이트 ──"
  ACTIVE_HOOK="${HOOKS_PATH:+$HOOKS_PATH/pre-push}"
  if [ -n "$ACTIVE_HOOK" ] && [ -f "$ACTIVE_HOOK" ] && grep -q "harness-setup:e2e-prepush" "$ACTIVE_HOOK" 2>/dev/null; then
    echo "✅ pre-push 게이트 활성 — core.hooksPath=$HOOKS_PATH"
    if [ -x node_modules/.bin/playwright ]; then
      echo "✅ playwright 실행 가능"
    else
      echo "ℹ️ playwright 미설치 — E2E 게이트는 no-op (validate만 실행)"
    fi
  elif [ -f .githooks/pre-push ] && grep -q "harness-setup:e2e-prepush" .githooks/pre-push 2>/dev/null; then
    echo "⚠️ pre-push 훅(.githooks/pre-push)은 있으나 비활성 — 활성화: git config core.hooksPath .githooks"
  else
    echo "⚠️ pre-push 마커 미발견 — 게이트 미설치 (e2e.prePush 옵트인 필요)"
  fi
fi

# 종합 판정
echo ""
echo "═══ 판정 ═══"
if [ "$STRUCT_FAIL" -eq 0 ] && [ "$QUALITY_FAIL" -eq 0 ]; then
  if [ "$Q2_UNENFORCED" -eq 1 ]; then
    echo "⚠️ MVH 가동 (Q2 미강제) — structural-test에 기계 검사 규칙이 없습니다"
    echo "   아키텍처 제약이 문서에만 있고 기계적으로 강제되지 않습니다 (체크리스트 §3.2 미충족 → 표준 아님)"
    echo "   → ARCHITECTURE.md를 수동 준수하거나 layers.rules/extraArchitectureRules로 검사 규칙을 추가하세요"
    exit 0
  fi
  echo "✅ 표준 하네스 가동 — 구조·실행 항목 통과"
  echo "ℹ️ 이 판정은 구조 설치+실행 가능성만 확인합니다 — 문서·규칙의 의미 정확성(분류·의존성 규칙이 옳은지)은 별도 검토 권장"
  exit 0
elif [ "$STRUCT_FAIL" -eq 0 ]; then
  echo "⚠️ 하네스 구조 정상 — 프로젝트 품질 검증 실패 (④⑤ 항목 확인)"
  exit 1
else
  echo "❌ 하네스 구조 점검 실패 (①②③ 항목 확인) — 하네스 재생성 또는 업그레이드 권장"
  exit 1
fi
