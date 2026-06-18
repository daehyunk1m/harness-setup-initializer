#!/bin/bash
# 하네스 자가진단 — 판정 기준: 하네스 구성 체크리스트 § 8 (harness-setup 스킬)
# 사용법: npm run harness:check
# exit 0 = 표준 하네스 가동 또는 의존성 미설치 보류(구조 정상), exit 1 = 점검 실패 (아래 ❌ 항목 참조)
#
# 항목 구분:
#   하네스 구조 (①②③) — 실패 시 하네스 자체가 깨진 상태
#   프로젝트 품질 (④⑤) — 실패 시 하네스는 정상이나 코드 검증이 깨진 상태
#   경고 전용 (⑥⑦⑧⑨⑩) — exit code에 영향 없음
# node_modules 부재 시: 품질 항목(④⑤)을 '의존성 미설치로 보류'로 표기하고 exit 0 (전이적 상태 — install 1회로 자가 해소, 하네스 결함 아님)

STRUCT_FAIL=0
QUALITY_FAIL=0
Q2_UNENFORCED=0
DEPS_MISSING=0

echo "═══ 하네스 자가진단 ═══"
echo ""

# ① 필수 파일/디렉토리 존재
echo "── ① 필수 파일 ──"
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt \
         feature_list.json .harness-friction.jsonl .harness-intent.jsonl init.sh scripts/structural-test.ts scripts/doc-freshness.ts; do
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
if [ -f docs/product-specs/README.md ] && [ -f docs/product-specs/_template.md ]; then
  echo "✅ docs/product-specs/ substrate (README·_template)"
else
  echo "❌ docs/product-specs/ substrate 없음 (README·_template)"; STRUCT_FAIL=1
fi
# 작성된 PRD({id}-{slug}.md) 부재는 실패가 아니라 보류 — 새 프로젝트는 PRD 0개가 정상
if [ "$(ls docs/product-specs/*.md 2>/dev/null | grep -cvE '/(README|_template)\.md$')" -gt 0 ]; then
  echo "✅ 작성된 PRD 존재"
else
  echo "⏸️ 작성된 PRD 없음 — 보류(온디맨드 작성, 실패 아님)"
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

# 의존성 사전 점검 — node_modules 부재 시 품질 항목(④⑤)은 실행 불가
# 하네스 결함이 아니라 전이적 상태(npm install 1회로 자가 해소)다. 자동 설치는 하지 않는다(절대 규칙).
echo ""
echo "── 의존성 사전 점검 ──"
if [ -f package.json ] && [ ! -d node_modules ]; then
  DEPS_MISSING=1
  echo "⏸️ node_modules 부재 — 품질 항목(④⑤)을 '의존성 미설치로 보류'로 표기 (구조 ①②③은 정상 판정)"
else
  echo "✅ 의존성 확인 — 품질 항목 정상 실행"
fi

# ④ 아키텍처 검증 (exit code 전파)
echo ""
echo "── ④ 아키텍처 검증 ──"
if [ "$DEPS_MISSING" -eq 1 ]; then
  echo "⏸️ 의존성 미설치로 보류 — node_modules 설치 후 재실행하면 판정됩니다"
elif {{LINT_ARCH_COMMAND}}; then
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
if [ "$DEPS_MISSING" -eq 1 ]; then
  echo "⏸️ 의존성 미설치로 보류 — node_modules 설치 후 재실행하면 판정됩니다"
elif {{VALIDATE_COMMAND}}; then
  echo "✅ validate 통과"
else
  echo "❌ validate 실패"
  QUALITY_FAIL=1
fi

# ⑥ 문서 최신성 (경고만 — doc-freshness는 항상 exit 0)
echo ""
echo "── ⑥ 문서 최신성 ──"
if [ "$DEPS_MISSING" -eq 1 ]; then
  echo "⏸️ 의존성 미설치로 보류 (doc:check는 경고 전용)"
else
  {{DOC_CHECK_COMMAND}} || true
fi

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

# ⑩ PRD 마커 위생 (경고 전용 — exit code 무영향; substrate 존재 시에만 실질 검사)
# --- harness:prd-marker-hygiene:start (test/prd-marker-hygiene-fixtures.sh가 이 블록을 추출·source한다 — 단일 소스, 로직 복사 금지) ---
prd_marker_hygiene() {
  local specs="docs/product-specs"
  if [ ! -f "$specs/README.md" ] || [ ! -f "$specs/_template.md" ]; then
    echo "⏸️ product-specs substrate 부재 — PRD 위생 보류 (① 참조)"
    return 0
  fi
  local prds
  prds=$(ls "$specs"/*.md 2>/dev/null | grep -vE '/(README|_template)\.md$')
  if [ -z "$prds" ]; then
    echo "⏸️ 작성된 PRD 없음 — PRD 위생 보류 (온디맨드 작성, 정상)"
    return 0
  fi
  local ids
  ids=$(node -e "const a=require('./feature_list.json'); process.stdout.write((Array.isArray(a)?a:[]).map(function(f){return f&&f.id;}).filter(Boolean).join('\n'))" 2>/dev/null)
  if [ -z "$ids" ]; then
    echo "ℹ️ feature_list.json 비어있음/없음 — feature id 대조(invalid-feature/mismatch) 보류, 나머지 마커 위생은 계속"
  fi
  local warn=0
  local -a seen=()
  local prd base mcount mid stem fileid dups d
  while IFS= read -r prd; do
    [ -n "$prd" ] || continue
    base=$(basename "$prd")
    mcount=$(grep -cE '^@feature:[^[:space:]]+$' "$prd" 2>/dev/null); mcount=${mcount:-0}
    if [ "$mcount" -eq 0 ]; then
      echo "⚠️ unbound-prd: $base — 전체줄 @feature 마커 없음 (바인딩 누락)"; warn=1; continue
    fi
    if [ "$mcount" -gt 1 ]; then
      echo "⚠️ multiple-markers: $base — 전체줄 @feature 마커 ${mcount}개 (1개만 두세요)"; warn=1; continue
    fi
    mid=$(grep -oE '^@feature:[^[:space:]]+$' "$prd" 2>/dev/null | head -1 | sed 's/^@feature://')
    seen+=("$mid")
    if [ -n "$ids" ] && ! printf '%s\n' "$ids" | grep -Fxq "$mid"; then
      echo "⚠️ invalid-feature: $base — @feature:$mid 가 feature_list.json에 없음 (오타/미등록)"; warn=1
    fi
    stem=${base%.md}
    if [ "$stem" = "$mid" ] || [ "${stem#"$mid"-}" != "$stem" ]; then
      :  # 파일명-마커 일치 — 무경고
    else
      # 유효 id 중 stem의 접두인 가장 긴 id (하이픈 id 안전; awk·서브셸·중첩 heredoc 미사용)
      fileid=""
      set -f  # ids는 공백 없는 식별자 — 단어분할만 쓰고 glob 확장은 막는다
      for cand in $ids; do
        if [ "$stem" = "$cand" ] || [ "${stem#"$cand"-}" != "$stem" ]; then
          [ ${#cand} -gt ${#fileid} ] && fileid="$cand"
        fi
      done
      set +f
      if [ -n "$fileid" ] && [ "$fileid" != "$mid" ]; then
        echo "⚠️ file-marker-mismatch: $base — 파일명 id($fileid) ≠ 마커 id($mid)"; warn=1
      fi
    fi
  done <<PRD_LIST
$prds
PRD_LIST
  if [ ${#seen[@]} -gt 0 ]; then
    dups=$(printf '%s\n' "${seen[@]}" | sort | uniq -d)
    if [ -n "$dups" ]; then
      while IFS= read -r d; do
        [ -n "$d" ] || continue
        echo "⚠️ duplicate-binding: feature $d 를 PRD 복수가 바인딩 (canonical 1개 권장)"; warn=1
      done <<DUP_LIST
$dups
DUP_LIST
    fi
  fi
  [ "$warn" -eq 0 ] && echo "✅ PRD 마커 위생 정상"
  return 0
}
# --- harness:prd-marker-hygiene:end ---
# --- harness:prd-section-body:start (canonical 실행 소스 — test/prd-content-hygiene-fixtures.sh·test/intent-prd-coverage-fixtures.sh가 추출·source. intent-distill SKILL.md §4.1은 동일 로직 doc 사본이며 test/prd-section-body-drift.sh가 동기 보장 — 로직 복사 금지) ---
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
# --- harness:prd-section-body:end ---
echo ""
echo "── ⑩ PRD 위생 ──"
prd_marker_hygiene

# 종합 판정
echo ""
echo "═══ 판정 ═══"
if [ "$STRUCT_FAIL" -ne 0 ]; then
  echo "❌ 하네스 구조 점검 실패 (①②③ 항목 확인) — 하네스 재생성 또는 업그레이드 권장"
  exit 1
elif [ "$DEPS_MISSING" -eq 1 ]; then
  echo "⏸️ 의존성 미설치 — 하네스 구조는 정상, 품질 항목(④⑤)은 node_modules 부재로 보류"
  echo "   → npm install (또는 yarn/pnpm install) 후 npm run harness:check 재실행 시 표준 하네스 판정 예상"
  echo "   ℹ️ 하네스 결함이 아닌 의존성 미설치입니다 — 하네스는 의존성을 자동 설치하지 않습니다"
  exit 0
elif [ "$QUALITY_FAIL" -eq 0 ]; then
  if [ "$Q2_UNENFORCED" -eq 1 ]; then
    echo "⚠️ MVH 가동 (Q2 미강제) — structural-test에 기계 검사 규칙이 없습니다"
    echo "   아키텍처 제약이 문서에만 있고 기계적으로 강제되지 않습니다 (체크리스트 §3.2 미충족 → 표준 아님)"
    echo "   → ARCHITECTURE.md를 수동 준수하거나 layers.rules/extraArchitectureRules로 검사 규칙을 추가하세요"
    exit 0
  fi
  echo "✅ 표준 하네스 가동 — 구조·실행 항목 통과"
  echo "ℹ️ 이 판정은 구조 설치+실행 가능성만 확인합니다 — 문서·규칙의 의미 정확성(분류·의존성 규칙이 옳은지)은 별도 검토 권장"
  exit 0
else
  echo "⚠️ 하네스 구조 정상 — 프로젝트 품질 검증 실패 (④⑤ 항목 확인)"
  exit 1
fi
