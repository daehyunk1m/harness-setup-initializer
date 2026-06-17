# Phase 2b-3 Increment 1 — PRD 마커 정적 위생 검사 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `harness-check.sh`에 경고-전용 섹션 ⑩을 추가해, 작성된 PRD 파일의 결정적 마커 위반 5종을 `grep`+`node -e`만으로 상시 검출한다.

**Architecture:** ⑩ 검사 로직을 `prd_marker_hygiene` bash 함수로 캡슐화하고 추출 마커 주석으로 감싼다. 골든 픽스처가 템플릿에서 이 함수를 sed로 추출·source해 실제 코드를 직접 테스트한다(단일 소스 — 로직 복사 없음). 전부 exit 0 경고. awk·신규 파일(픽스처 제외)·신규 플레이스홀더 0.

**Tech Stack:** bash 3.2(macOS 호환), `grep -E`, `node -e`(feature_list.json 읽기), 골든 픽스처 패턴(`test/*-fixtures.sh`).

## Global Constraints

- **exit 0 경고-전용** — ⑩의 모든 위반은 경고. `STRUCT_FAIL`/`QUALITY_FAIL`/exit code에 무영향. managed substrate(README/_template) 부재만 기존 ① 그대로 exit 1.
- **신규 플레이스홀더 0** — ⑩은 `{{...}}` 치환 토큰을 도입하지 않는다(경로·패턴 하드코딩 상수). 프로필 필드 0, manifest 카테고리 불변.
- **awk 0** — 마커 검사는 순수 grep/파일명/feature_list 집합. `prd_section_body` awk는 사용하지 않는다(내용 파싱 = Increment 2).
- **bash 3.2 호환** — macOS 기본 셸. `local -a`/`+=`/`${#arr[@]}` 사용 가능, 빈 배열은 가드.
- **오탐 보수성** — 결정적·명확한 위반만 경고. slug-only 파일명·본문 인라인 마커·README/_template은 침묵.
- **MINOR v1.28.0** — 하위 호환, managed 자동 감지(§12.6) 전파, 마이그레이션 불필요.
- 커밋 메시지: `type(scope): 설명` (한국어, 첫 줄 ≤72자). 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- 스펙 정본: `docs/superpowers/specs/2026-06-18-phase-2b-3-prd-hygiene-design.md`.

---

### Task 1: harness-check.sh ⑩ PRD 마커 위생 함수 + 골든 픽스처

**Files:**
- Modify: `skills/harness-scaffold/templates/harness-check.sh` (⑨ 다음 ~190행, "종합 판정"(~192행) 앞에 ⑩ 삽입)
- Create: `test/prd-marker-hygiene-fixtures.sh`

**Interfaces:**
- Produces: bash 함수 `prd_marker_hygiene()` — CWD를 프로젝트 루트로 가정, `docs/product-specs/`·`feature_list.json`을 읽어 경고를 stdout에 출력, 항상 `return 0`. 추출 마커 `# --- harness:prd-marker-hygiene:start ---` / `# --- harness:prd-marker-hygiene:end ---` 사이에 정의.
- Consumes: 없음(첫 태스크).

- [ ] **Step 1: 골든 픽스처 작성 (RED — 함수 미정의)**

Create `test/prd-marker-hygiene-fixtures.sh`:

```bash
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
```

- [ ] **Step 2: 픽스처 실행 → RED 확인**

Run: `bash test/prd-marker-hygiene-fixtures.sh`
Expected: FAIL — "❌ 템플릿에서 prd_marker_hygiene 함수 추출 실패" (함수 미정의, exit 1)

- [ ] **Step 3: harness-check.sh에 ⑩ 함수 + 섹션 삽입 (GREEN)**

`skills/harness-scaffold/templates/harness-check.sh`의 ⑨ 블록(`# ⑨ pre-push 게이트 …` ~ 마지막 `fi`, ~190행)과 `# 종합 판정`(~192행) **사이**에 다음을 삽입한다:

```bash
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
echo ""
echo "── ⑩ PRD 위생 ──"
prd_marker_hygiene

```

- [ ] **Step 4: 픽스처 실행 → GREEN 확인**

Run: `bash test/prd-marker-hygiene-fixtures.sh`
Expected: PASS — "✅ 전부 통과" (T1~T14, FAIL=0, exit 0)

- [ ] **Step 5: 회귀 — 기존 PRD/structural 픽스처 통과 확인**

Run: `bash test/prd-substrate-fixtures.sh && bash test/intent-prd-coverage-fixtures.sh && bash test/run-fixtures.sh`
Expected: 셋 다 "✅ 전부 통과" / exit 0 (⑩ 추가가 기존 검사에 영향 없음)

- [ ] **Step 6: 커밋**

```bash
git add skills/harness-scaffold/templates/harness-check.sh test/prd-marker-hygiene-fixtures.sh
git commit -m "$(cat <<'EOF'
feat(templates): harness-check ⑩ PRD 마커 위생 검사 (이슈 #15 2b-3)

작성된 PRD 파일의 결정적 마커 위반 5종(unbound/multiple/invalid-feature/
file-marker-mismatch/duplicate-binding)을 grep+node -e로 검출. 전부 exit 0
경고, substrate/PRD 부재 보류. 골든 픽스처가 템플릿에서 함수를 추출·source
(단일 소스). awk·신규 플레이스홀더 0.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: SSoT 동기화 (checklist §8/§1.1 + scaffold §5.14)

**Files:**
- Modify: `skills/harness-setup/references/harness-checklist.md` (§1.1 ~39행 보류 노트 직후, §8 마지막 노트)
- Modify: `skills/harness-scaffold/SKILL.md` (§5.14 harness-check 생성 규칙 ~991행)

**Interfaces:**
- Consumes: Task 1의 ⑩ 동작(경고-전용, substrate 존재 시 검사).
- Produces: 문서 정합(검사 SSoT가 ⑩을 기술). 후속 태스크 의존 없음.

- [ ] **Step 1: checklist §1.1에 마커 위생 노트 추가**

`skills/harness-setup/references/harness-checklist.md`의 §1.1, `> 작성된 PRD(...) 부재는 **보류**...` 줄(~39행) **직후**에 다음 한 줄을 추가:

```markdown
  > 작성된 PRD의 **마커 위생**(전체줄 `@feature` 1개·유효 feature·파일명 일치·중복 없음)은 harness-check ⑩이 검사한다 — **경고 전용(exit 0)**, 위반이 하네스를 깨지 않는다.
```

- [ ] **Step 2: checklist §8 마지막 노트의 항목 수·범위 갱신**

`skills/harness-setup/references/harness-checklist.md` §8 마지막 인용 줄을 아래와 같이 교체:

찾기:
```markdown
> 생성된 하네스에서는 위 6개 명령이 `npm run harness:check` 하나로 통합되어 있다
> (`scripts/harness-check.sh` — tsconfig paths 검사 + E2E 스캐폴드 구조(⑧) 포함 8항목).
```
교체:
```markdown
> 생성된 하네스에서는 위 6개 명령이 `npm run harness:check` 하나로 통합되어 있다
> (`scripts/harness-check.sh` — tsconfig paths(⑦)·E2E 스캐폴드 구조(⑧)·pre-push(⑨)·PRD 마커 위생(⑩) 포함).
> ⑩ PRD 마커 위생은 **경고 전용(exit 0)** — substrate 존재 시 작성 PRD의 마커 위반 5종(unbound/multiple/invalid-feature/file-marker-mismatch/duplicate-binding)을 검출하며, 위반은 판정에 영향을 주지 않는다(managed substrate 부재만 ①에서 exit 1).
```

- [ ] **Step 3: scaffold SKILL §5.14에 ⑩ 생성 기술 추가**

`skills/harness-scaffold/SKILL.md` §5.14의 `- 전체 통과 시 "✅ 표준 하네스 가동"을 출력한다 ...` 줄(~1005행) **직후**에 한 줄 추가:

```markdown
- 템플릿에는 ⑩ PRD 마커 위생 검사(`prd_marker_hygiene` 함수, 경고 전용·exit 0)가 포함된다 — substrate 존재 시 작성 PRD의 전체줄 `@feature` 마커 위생(unbound/multiple/invalid-feature/file-marker-mismatch/duplicate-binding)을 검출한다. 신규 플레이스홀더 없음(경로·패턴 하드코딩). 판정 기준: `references/harness-checklist.md` § 8.
```

- [ ] **Step 4: 미치환 플레이스홀더 회귀 확인**

Run: `grep -nE '\{\{[A-Z_]+\}\}' skills/harness-scaffold/templates/harness-check.sh`
Expected: ⑩ 블록에는 매칭 0건 (기존 {{LINT_ARCH_COMMAND}} 등만 출력 — ⑩이 신규 플레이스홀더를 도입하지 않았음을 확인)

- [ ] **Step 5: 커밋**

```bash
git add skills/harness-setup/references/harness-checklist.md skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
docs(skill): ⑩ PRD 마커 위생 SSoT 동기화 (이슈 #15 2b-3)

harness-checklist §1.1/§8 + harness-scaffold §5.14에 ⑩ 검사(경고 전용,
5종 위반) 기술. 검사 SSoT와 생성 규칙 정합.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 버전 범프 v1.28.0 + 트래킹

**Files:**
- Modify: `skills/harness-setup/references/project-context.md` (버전 히스토리 + 설계 결정)
- Modify: `.tracking/CHANGELOG.md` (Added)
- Modify: `.claude-plugin/plugin.json` (version)
- Modify: `README.md` (버전 줄)
- Modify: `.tracking/HANDOFF.md` (현재 버전·다음 작업)
- Modify: `.tracking/TODO.md` (2b-3 Increment 1 완료 기록)

**Interfaces:**
- Consumes: Task 1·2 완료 상태.
- Produces: 릴리스 준비 완료 상태 + v1.28.0 태그.

**참고**: 프로필/매니페스트 스키마의 `version` 필드는 **범프하지 않는다** — Public API(프로필 4계약) 무변경(MINOR, 항목 추가). 두 SKILL.md의 프로필 스키마 JSON 블록은 byte-identical 유지(변경 없음).

- [ ] **Step 1: 현재 버전 문자열 위치 확인**

Run: `grep -rn '1\.27\.0' skills/harness-setup/references/project-context.md .claude-plugin/plugin.json README.md | head`
Expected: 각 파일의 현재 버전 줄 위치 출력 (교체 대상 확인)

- [ ] **Step 2: plugin.json·README 버전 범프**

`.claude-plugin/plugin.json`의 `"version": "1.27.0"` → `"version": "1.28.0"`.
`README.md`의 버전 줄(`grep 1.27.0` 결과 위치) `1.27.0` → `1.28.0`.

- [ ] **Step 3: project-context.md 버전 히스토리 + 설계 결정 추가**

`skills/harness-setup/references/project-context.md` 버전 히스토리 최상단에 추가:
```markdown
- **1.28.0** (2026-06-18): Phase 2b-3 Increment 1 — PRD 마커 정적 위생 검사. harness-check ⑩(경고 전용·exit 0) — 작성된 PRD의 마커 위반 5종(unbound-prd/multiple-markers/invalid-feature/file-marker-mismatch/duplicate-binding)을 grep+node -e로 검출. substrate/PRD 부재 보류. 골든 픽스처가 템플릿에서 `prd_marker_hygiene` 함수를 추출·source(단일 소스). 멀티모델 자문 반영: exit 0 경고-전용, 8-상태 라벨 축소(ambiguous-marker·stub-only 시맨틱 기각), awk-free(내용 파싱·교차검사·doc-freshness 글로빙은 Inc2/기각). 신규 플레이스홀더·프로필 필드 0, 마이그레이션 불필요. MINOR.
```
§ 설계 결정 사항에 추가:
```markdown
- **2b-3 Increment 1 경계 (마커 위생만)**: feature↔PRD 교차 검사는 "PRD 없음 정상(온디맨드)"(product-specs README)과 충돌해 새 프로젝트에서 경고 폭탄 → Inc2 이연. 빈 섹션 검사는 `prd_section_body` awk 필요 → Inc2(거기서 공유 헬퍼 결정). doc-freshness 글로빙은 mtime 노이즈로 기각(멀티모델 자문 합의). Increment 1을 awk-free 순수 grep으로 한정해 awk 3중화 부채를 회피.
```

- [ ] **Step 4: CHANGELOG 추가**

`.tracking/CHANGELOG.md`의 최신 버전 블록 위에 추가:
```markdown
## [1.28.0] — 2026-06-18

### 추가 (Added)
- **harness-check ⑩ PRD 마커 위생** (이슈 #15 Phase 2b-3 Increment 1): 작성된 PRD 파일의 결정적 마커 위반 5종(unbound-prd·multiple-markers·invalid-feature·file-marker-mismatch·duplicate-binding)을 `grep`+`node -e`로 검출. 전부 **exit 0 경고-전용**, substrate/작성 PRD 부재는 보류. `prd_marker_hygiene` 함수를 추출 마커로 감싸 골든 픽스처(`test/prd-marker-hygiene-fixtures.sh`, T1~T12)가 템플릿에서 추출·source(단일 소스, 로직 복사 없음).
- harness-checklist §1.1/§8 + harness-scaffold §5.14 ⑩ 동기화.

### 설계 (Design)
- 멀티모델 자문(codex·gemini): exit 0 경고-전용, 8-상태 라벨 축소(시맨틱 `ambiguous-marker`·`stub-only` 기각), awk-free(내용 파싱은 Inc2), doc-freshness 글로빙 기각, 교차검사 Inc2 이연. 정본: `docs/superpowers/specs/2026-06-18-phase-2b-3-prd-hygiene-design.md`.
- 신규 플레이스홀더·프로필 필드 0, managed 자동 감지 전파, 마이그레이션 불필요. MINOR.
```

- [ ] **Step 5: HANDOFF·TODO 갱신**

`.tracking/HANDOFF.md`:
- "현재 버전: 1.27.0" → "1.28.0" + 한 줄 요약 추가(2b-3 Inc1 종결).
- "▶ 다음 작업"을 Phase 2b-3 Increment 2(빈 섹션 경고 + feature↔PRD 교차, awk 공유 헬퍼 결정)로 갱신. P7 커버리지 행에 1.28.0 한 문장 추가.

`.tracking/TODO.md`: Phase 2b-3 Increment 1 완료 항목 기록(5종 검사·픽스처 T1~T12·SSoT 동기화), Increment 2 후보(빈 섹션·교차·공유 헬퍼) 이월.

- [ ] **Step 6: 전체 회귀 + 커밋 + 태그**

Run: `bash test/prd-marker-hygiene-fixtures.sh && bash test/prd-substrate-fixtures.sh && bash test/run-fixtures.sh`
Expected: 전부 exit 0

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(tracking): 1.28.0 범프 + 2b-3 Inc1 트래킹 (이슈 #15)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
git tag -a v1.28.0 -m "Phase 2b-3 Increment 1 — PRD 마커 정적 위생 검사"
```

---

## Self-Review

**1. Spec coverage** (스펙 §별 → 태스크):
- §3 스코프·경계(검사 대상·보류·위치) → Task 1 Step 3(함수 가드 + ⑩ 배치)
- §4 검사 5종 + §4.1 하이픈 id 규칙 → Task 1 Step 3 함수 본문, Step 1 T1~T8 검증
- §5 오탐 가드(README/_template 제외·전체줄·slug-only 침묵) → Task 1 T8·T11
- §6 exit 정책·8-상태 라벨 축소 → Global Constraints + Task 1(경고만, 5라벨) ; `ambiguous-marker`/`stub-only` 미구현(설계 기각, 코드에 없음 = 일관)
- §7 동기화 지점 → Task 2(checklist §1.1/§8, scaffold §5.14), Task 1(harness-check.sh)
- §8 검증 계획 T1~T11 → Task 1 픽스처 T1~T11 + 추가 T12(render-after 와이어링)
- §9 비-스코프 → Task 3 Step 3 설계 결정 기록(이연/기각 명문화)
- §10 진입점·버전 → Task 3(v1.28.0 범프·태그)

**2. Placeholder scan**: "TBD/TODO/적절히/등" 없음. 모든 코드 단계에 실제 코드·정확 경로·기대 출력 포함. ✅

**3. Type consistency**: 함수명 `prd_marker_hygiene`·추출 마커 `harness:prd-marker-hygiene:start/end`·경고 접두(`⚠️ unbound-prd:`/`multiple-markers:`/`invalid-feature:`/`file-marker-mismatch:`/`duplicate-binding:`)·정상(`✅ PRD 마커 위생 정상`)·보류(`⏸️ ...`)가 Task 1 함수 정의·픽스처 assert·Task 2 문서에서 동일. ✅
