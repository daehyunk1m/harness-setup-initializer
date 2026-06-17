# Intent→PRD Coverage Derive (Phase 2b-2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `intent-distill`에 forward PRD 커버리지 derive를 추가해 2b-1 substrate를 live하게 만들고, `INTENT_BACKLOG.md`를 2차원(prd_state+e2e_state)으로 확장한다.

**Architecture:** intent-distill의 기존 E2E derive 옆에 PRD derive 스테이지를 병렬 추가한다. PRD 바인딩은 2b-1의 whole-line `@feature` 프리미티브 재사용, 섹션 경계는 정적 앵커, 빈 섹션 가드는 결정적 awk 추출기로 구현(테스트 가능). substrate 부재는 `blocked:*`로 `missing`과 분리. 백로그는 skill-내부 one-way 마이그레이션으로 구 E2E-only 행을 승격.

**Tech Stack:** Markdown 스킬 사양(LLM 실행 프로즈 + `!`/bash 스니펫), Bash 골든 픽스처(결정적 기계: 바인딩 grep·섹션 추출·헤더 구조).

## Global Constraints

- **forward-only** — 역방향 "미검증 명세" 구현 안 함.
- substrate 부재 = `blocked:no-prd-substrate` / `blocked:no-e2e-substrate` — **절대 `missing`과 혼동 금지**.
- PRD 5-상태 = `covered`/`partial`/`missing`/`ambiguous`/`invalid-feature`. 보수적: 불확실→`ambiguous`; **빈 섹션·템플릿 주석·README는 절대 `covered` 금지 → `missing`**.
- PRD 바인딩 = `grep -Rl -Fx "@feature:{feature}" docs/product-specs/` (whole-line 리터럴, 2b-1 규칙).
- kind↔섹션: `intended`→behavior/acceptance, `unintended`→edge-cases/open-questions.
- 백로그 행 = `| key(ts) | feature | surface | kind | statement | prd_state | e2e_state | evidence | priority/비고 |`. derived 컬럼 vs **사용자 편집은 priority/비고 단일**. 행 제거는 **둘 다 covered(또는 waiver)일 때만**.
- 마이그레이션 = one-way 승격(`state→e2e_state`, 구 `evidence`→통합 `evidence`의 e2e 부분, `prd_state` 신규 derive), **priority/비고·미지 컬럼·waiver 보존**, idempotent.
- `encoded` 미갱신 · 원장 스키마 불변 · 신규 프로필 필드 0 · 신규 `{{플레이스홀더}}` 0 · INTENT_BACKLOG `data` 카테고리 불변(scaffold 마이그레이션 레지스트리 항목 없음).
- E2E derive(2a) 회귀 0. MINOR 1.26.0→1.27.0.
- 커밋: `type(scope): 설명`(한국어 ≤72자) + `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. 브랜치 `feature/phase-2b-2-prd-coverage`(생성됨).

**섹션 본문 추출기 (정적 idiom — Task 1 픽스처와 Task 3 §4가 동일하게 사용):**
```bash
prd_section_body() {  # args: <section-name> <prd-file> → 섹션 산문 본문만(앵커·HTML주석·헤딩·공백 제외)
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
```
빈 출력 = 섹션 비어있음 → **`covered` 금지(→ missing)**. 비어있지 않으면 LLM이 의미 매칭 판정.

---

### Task 1: 백로그 템플릿 2차원 헤더 + 골든 픽스처

**Files:**
- Modify: `skills/harness-scaffold/templates/INTENT_BACKLOG.md`
- Test: `test/intent-prd-coverage-fixtures.sh`

**Interfaces:**
- Produces: 2차원 헤더 백로그 템플릿(신규 셋업용) + 결정적 기계 검증 픽스처(바인딩 grep · 섹션 추출기 · 헤더 구조). 후속 Task들이 헤더 컬럼명·추출기 idiom·바인딩 규칙을 참조한다.

- [ ] **Step 1: 픽스처를 먼저 작성한다**

`test/intent-prd-coverage-fixtures.sh`:

```bash
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
{ grep -qv "| state |" "$BL" 2>/dev/null && ! grep -qE '\| *state *\|' "$BL" && ok "구 단일 state 컬럼 제거"; } || no "구 state 컬럼 잔존"
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
```

- [ ] **Step 2: 픽스처를 실행해 실패를 확인한다**

Run: `chmod +x test/intent-prd-coverage-fixtures.sh && bash test/intent-prd-coverage-fixtures.sh`
Expected: FAIL — T1이 `prd_state`/`e2e_state` 부재로 실패(`FAIL>0`, exit 1). T2/T3는 통과(템플릿 무관 idiom).

- [ ] **Step 3: 백로그 템플릿 헤더를 2차원으로 교체한다**

`skills/harness-scaffold/templates/INTENT_BACKLOG.md`를 다음으로 교체:

```markdown
# 의도 커버리지 백로그

> `intent-distill`이 `.harness-intent.jsonl` ↔ `@feature` PRD·E2E를 대조해 2차원 커버리지를 동기화하는 영속 백로그다.
> 두 차원(prd_state·e2e_state) 모두 covered(또는 waiver)인 의도는 제거되고, 갭만 남는다.
> **derived 컬럼(prd_state·e2e_state·evidence)은 매 실행 재산출 — 사용자 편집은 `priority/비고` 컬럼만.**
> "의도 정리" / "커버리지 분석"으로 동기화한다.

## 열린 백로그

| key(ts) | feature | surface | kind | statement | prd_state | e2e_state | evidence | priority/비고 |
|---------|---------|---------|------|-----------|-----------|-----------|----------|---------------|
<!-- intent-distill이 갭(둘 중 한 차원이라도 missing/partial/ambiguous/invalid-feature, 또는 blocked)을 여기에 동기화한다. key=의도 ts. prd_state/e2e_state는 5-상태 또는 blocked:no-*-substrate. priority/비고 열은 사용자 소유(머지 보존). -->

## waiver (재추가 안 함)

| key(ts) | statement | 사유 |
|---------|-----------|------|
<!-- "안 함"으로 판정한 의도를 사용자가 여기에 옮기면 distill이 열린 백로그에 재추가하지 않는다. (예: "PRD 불필요"·"E2E 불필요" 메모도 priority/비고에 남기면 해당 차원 갭이 다시 떠도 노이즈로 취급) -->
```

- [ ] **Step 4: 픽스처를 실행해 통과를 확인한다**

Run: `bash test/intent-prd-coverage-fixtures.sh`
Expected: PASS — `FAIL=0`, "✅ 전부 통과", exit 0.

- [ ] **Step 5: 커밋**

```bash
git add skills/harness-scaffold/templates/INTENT_BACKLOG.md test/intent-prd-coverage-fixtures.sh
git commit -m "$(cat <<'EOF'
feat(templates): INTENT_BACKLOG 2차원 헤더 + 골든 픽스처 (이슈 #15 Phase 2b-2)

prd_state/e2e_state 2차원 + derived/user 분리 노트. 픽스처: 바인딩
grep(-Fx)·섹션 추출기·빈섹션 가드(false-covered 방지) 결정적 검증.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: substrate 게이팅 차원별 분해 (§3)

**Files:**
- Modify: `skills/intent-distill/SKILL.md` (§3 ~line 35-41)

**Interfaces:**
- Produces: §3가 E2E·PRD substrate를 독립 확인하고 4조합 매트릭스를 정의. §4 derive가 이 게이트 결과(`blocked:no-*-substrate`)를 소비.

- [ ] **Step 1: §3을 차원별 substrate 확인으로 교체한다**

`skills/intent-distill/SKILL.md`의 현재 §3 블록 전체:

```markdown
## 3. E2E 계층 확인

```!
if [ -d e2e/specs ] && ls e2e/specs/*.e2e.ts >/dev/null 2>&1; then echo "E2E_PRESENT"; else echo "E2E_ABSENT"; fi
```

`E2E_ABSENT`이면: "이 프로젝트는 E2E 계층이 없어 커버리지 판정을 보류합니다(E2E 도입 후 재실행). 적재된 의도 {N}건은 'E2E 도입 후 판정' 상태입니다." 출력 후 **종료**한다 — 모든 의도를 missing으로 오판하지 않는다.
```

→ 다음으로 교체:

````markdown
## 3. substrate 확인 (차원별 독립)

PRD·E2E 두 차원을 **독립**으로 확인한다. 한 차원이 없으면 그 차원만 보류(`blocked:*`)하고 다른 차원은 정상 derive한다.

```!
if [ -d e2e/specs ] && ls e2e/specs/*.e2e.ts >/dev/null 2>&1; then echo "E2E_PRESENT"; else echo "E2E_ABSENT"; fi
if [ -d docs/product-specs ] && ls docs/product-specs/*.md >/dev/null 2>&1; then echo "PRD_PRESENT"; else echo "PRD_ABSENT"; fi
```

**게이팅 매트릭스** (substrate 부재 ≠ 미커버 — 절대 혼동 금지):

| PRD | E2E | 동작 |
|-----|-----|------|
| PRESENT | PRESENT | 두 차원 derive |
| PRESENT | ABSENT | PRD만 derive, 모든 의도 `e2e_state=blocked:no-e2e-substrate` |
| ABSENT | PRESENT | E2E만 derive, 모든 의도 `prd_state=blocked:no-prd-substrate` |
| ABSENT | ABSENT | "두 substrate(E2E·PRD)가 없어 커버리지 판정을 보류합니다. 적재된 의도 {N}건은 substrate 도입 후 판정됩니다." 출력 후 **종료** |

`docs/product-specs/`에 `README.md`/`_template.md`만 있고 바인딩 PRD가 없어도 PRD_PRESENT다(개별 feature의 PRD 부재는 §4에서 `missing`으로 판정 — substrate 부재와 구분).
````

- [ ] **Step 2: 일관성 확인 + 커밋**

Run: `grep -n "blocked:no-prd-substrate\|blocked:no-e2e-substrate\|PRD_ABSENT\|게이팅 매트릭스" skills/intent-distill/SKILL.md`
Expected: §3에 두 substrate 확인 + 매트릭스 + 두 blocked 상태가 출력된다.

```bash
git add skills/intent-distill/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): intent-distill substrate 게이팅 차원별 분해 (이슈 #15 Phase 2b-2)

§3 E2E 단일 보류 → PRD·E2E 독립 확인 + 4조합 매트릭스.
substrate 부재=blocked:no-*-substrate (missing과 분리).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: PRD 커버리지 derive (§4)

**Files:**
- Modify: `skills/intent-distill/SKILL.md` (§4 ~line 43-60)

**Interfaces:**
- Consumes: §3 게이트(`PRD_PRESENT`/`blocked:no-prd-substrate`), Global Constraints의 `prd_section_body` 추출기.
- Produces: 각 의도의 `prd_state`(5-상태/blocked) + 증거. §5 머지가 소비.

- [ ] **Step 1: §4 제목과 도입을 2차원으로 갱신한다**

`skills/intent-distill/SKILL.md`의 §4 제목 줄과 첫 문장:

```markdown
## 4. 커버리지 파생 (feature-범위, 증거 필수)

각 의도(intended+unintended)에 대해 5-상태를 산출한다:
```

→ 교체:

```markdown
## 4. 커버리지 파생 (feature-범위, 증거 필수, 2차원)

각 의도(intended+unintended)에 대해 **`prd_state`와 `e2e_state`를 각각** 산출한다. 두 차원은 독립이며 substrate 부재는 `blocked:no-*-substrate`로 기록한다(미커버 `missing`과 절대 혼동 금지). E2E 차원은 §4.2, PRD 차원은 §4.1.
```

- [ ] **Step 2: §4.1 PRD derive 서브섹션을 §4 도입 직후에 삽입한다**

§4 도입 문장 다음, 기존 1·2·3 번호 목록(E2E derive) **앞**에 삽입. 먼저 기존 목록을 `### 4.2 E2E 차원 (기존)` 헤딩으로 감싸고, 그 앞에 `### 4.1 PRD 차원 (신규)`을 둔다:

````markdown
### 4.1 PRD 차원 (신규)

각 의도의 `prd_state`:

1. `feature`가 `""`이거나 `feature_list.json`에 없으면 → **`invalid-feature`** (증거: "feature 미지정/미존재"). 다음 차원으로.
2. PRD substrate 부재(§3 PRD_ABSENT) → **`blocked:no-prd-substrate`** (증거: "docs/product-specs 없음 — 판정 불가"). **`missing` 아님.**
3. 바인딩 PRD를 **whole-line 리터럴**로 찾는다(2b-1 규칙):
   ```bash
   grep -Rl -Fx "@feature:{feature}" docs/product-specs/ 2>/dev/null
   ```
   매칭 PRD 없으면 → **`missing`** (증거: "@feature:{feature} PRD 없음 — 작성 후보").
4. 매칭 PRD 있으면 그 파일**만** 읽는다. kind에 맞는 섹션에서 근거 탐색:
   - `intended` → `behavior`·`acceptance` 섹션
   - `unintended` → `edge-cases`·`open-questions` 섹션
   섹션 본문은 정적 추출기로 얻는다(앵커는 경계로만, HTML 주석·`_template.md`/`README.md`·헤딩 제외):
   ```bash
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
   ```
   - **빈 섹션 가드**: 기대 섹션의 `prd_section_body` 출력이 비어있으면 → **`missing`** (증거: "기대 섹션 비어있음 — 명세 누락"). **`covered` 절대 금지** (템플릿 안내 주석·빈 헤딩을 명세로 오인 방지).
   - 본문이 있으면 의미 판정(**보수적** — PRD 산문은 약한 증거라 문턱 상향):
     - **`covered`**: statement의 핵심 행위 + 대상 + 조건/예외가 본문에 **명시**됨 (증거: PRD 경로 + 섹션 앵커명 + 인용 요지).
     - **`partial`**: feature PRD는 있으나 조건/예외/부정 방향 일부 누락 (증거: 경로 + 미커버 요지).
     - **`ambiguous`**: 표현이 일반적/상위 개념뿐이거나 매칭 불확실 — **불확실하면 기본값**(증거: 사유).
   - 동의어/동일 대상/동일 조건이 명확하지 않으면 `covered`로 올리지 말고 `ambiguous`/`partial`로 남긴다.

**모든 판정 증거 필수.** (최적화: 백로그에 `covered` 증거로 기록됐고 그 PRD 파일이 안 바뀐 의도는 PRD 재판정 스킵 가능.)

### 4.2 E2E 차원 (기존)
````

- [ ] **Step 3: 기존 E2E derive 목록을 §4.2 아래로 유지하고 blocked 상태를 추가한다**

기존 1·2·3 목록(`1. feature가 ""...` ~ `모호(statement 모호...)`)은 §4.2 헤딩 아래에 **그대로 유지**하되, E2E substrate 부재 처리를 위해 목록 2번 앞에 한 줄 추가:

```markdown
0. E2E substrate 부재(§3 E2E_ABSENT) → **`blocked:no-e2e-substrate`**. 아니면 아래 판정.
```

(기존 `**모든 판정에 증거 필수**`와 최적화 줄은 그대로 둔다.)

- [ ] **Step 4: 일관성 확인 + 커밋**

Run: `grep -n "### 4.1 PRD\|### 4.2 E2E\|blocked:no-prd-substrate\|빈 섹션 가드\|prd_section_body\|보수적" skills/intent-distill/SKILL.md`
Expected: §4.1/§4.2 헤딩, blocked 상태, 빈섹션 가드, 추출기 함수, 보수적 판정이 출력된다.

```bash
git add skills/intent-distill/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): intent-distill PRD 커버리지 derive §4.1 (이슈 #15 Phase 2b-2)

forward PRD derive — whole-line 바인딩, kind↔섹션, 빈섹션 가드(추출기),
보수적 5-상태(불확실=ambiguous). E2E는 §4.2로 유지 + blocked 상태.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: 백로그 읽기 + 2차원 머지·마이그레이션 (§2, §5)

**Files:**
- Modify: `skills/intent-distill/SKILL.md` (§2 ~line 27-33, §5 ~line 62-71)

**Interfaces:**
- Consumes: §4의 `prd_state`/`e2e_state`.
- Produces: 2차원 백로그 머지 + 구 E2E-only 백로그 one-way 승격. §6 리포트가 결과 소비.

- [ ] **Step 1: §2 백로그 읽기에 구-포맷 감지를 추가한다**

`skills/intent-distill/SKILL.md`의 §2 본문 줄:

```markdown
부재 시 빈 백로그(열린 백로그 0행, waiver 0행)로 시작한다. `## 열린 백로그` 표(키=ts)와 `## waiver` 표(키=ts)를 파싱하고, 사용자 `priority/비고` 열·waiver 항목을 **보존 대상**으로 기억한다.
```

→ 교체:

```markdown
부재 시 빈 백로그(열린 백로그 0행, waiver 0행)로 시작한다. `## 열린 백로그` 표(키=ts)와 `## waiver` 표(키=ts)를 파싱하고, 사용자 `priority/비고` 열·waiver 항목을 **보존 대상**으로 기억한다.

**구-포맷 감지**: 헤더에 `prd_state`/`e2e_state`가 없고 단일 `state`/`evidence` 컬럼이면 2a(E2E-only) 백로그다 → §5 마이그레이션으로 승격한다. 헤더에 **모르는 추가 컬럼**이 있으면(사용자가 표를 확장) 그 컬럼과 값을 key=ts로 **그대로 보존**한다.
```

- [ ] **Step 2: §5 머지를 2차원 + 마이그레이션으로 교체한다**

§5 전체:

```markdown
## 5. 백로그 머지 (idempotent)

키 = 의도 `ts`. 각 의도:
- `covered` → 열린 백로그에 있으면 **제거**(해소).
- `missing` / `partial` / `ambiguous` / `invalid-feature` → 열린 백로그에 **없으면 추가**, 있으면 `state`/`evidence` **갱신**.
- **waiver 섹션에 키가 있으면 스킵**(재추가 안 함).

기존 행의 사용자 `priority/비고` 열은 키 매칭으로 **보존**(덮어쓰기 아닌 머지). waiver 섹션은 distill이 수정하지 않는다. → 같은 입력 = 같은 백로그(재실행 동일).

statement를 표 셀에 넣을 때 **§7 이스케이프**를 적용한다.
```

→ 교체:

````markdown
## 5. 백로그 머지 (2차원, idempotent)

키 = 의도 `ts`. 각 의도에 대해 `prd_state`·`e2e_state`를 모두 기록한다.

**행 유지 규칙**:
- **둘 다 `covered`**(또는 waiver) → 열린 백로그에서 **제거**(완전 추적).
- 한 차원이라도 actionable 갭(`missing`/`partial`/`ambiguous`/`invalid-feature`) → 행 **유지/추가**, 두 상태 컬럼 + 통합 `evidence` 갱신.
- 두 차원이 `blocked:*`만(substrate 부재) → "판정 불가" 행으로 유지(보류 — 갭으로 단정 안 함).
- **waiver 섹션에 키가 있으면 스킵**(재추가 안 함). 사용자가 `priority/비고`에 "PRD 불필요"/"E2E 불필요"를 적었으면 해당 차원 갭은 노이즈로 취급(행은 유지하되 재-제안 안 함).

**evidence 컬럼**(통합): 두 차원 증거를 한 셀에 — 예 `prd: F007-progress.md#edge-cases (someday 제외 명시) · e2e: F007-progress.e2e.ts::"excludes someday"`.

**구-포맷 마이그레이션**(첫 2b-2 실행, §2에서 감지): 기존 E2E-only 행을 **one-way 승격**:
1. `state` → `e2e_state`(값 그대로).
2. 구 `evidence` → 통합 `evidence`의 e2e 부분으로 이동.
3. `prd_state` 신규 → 이번 실행에서 §4.1 derive(PRD substrate 없으면 `blocked:no-prd-substrate`).
4. `priority/비고` → key=ts 보존. **헤더에 없던 사용자 추가 컬럼은 끝에 그대로 보존.**
5. waiver 표 미수정.

derived 컬럼(prd_state·e2e_state·evidence)만 재작성하고 사용자 컬럼은 불변 → 같은 입력 = 같은 백로그(idempotent). 증거 요지는 핵심 명사·조건 인용으로 표현해 실행 간 diff를 최소화한다.

statement를 표 셀에 넣을 때 **§7 이스케이프**를 적용한다.
````

- [ ] **Step 3: 일관성 확인 + 커밋**

Run: `grep -n "구-포맷\|one-way 승격\|행 유지 규칙\|둘 다 .covered\|미지 컬럼\|추가 컬럼" skills/intent-distill/SKILL.md`
Expected: §2 구-포맷 감지 + §5 행 유지 규칙·마이그레이션·미지 컬럼 보존이 출력된다.

```bash
git add skills/intent-distill/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): intent-distill 2차원 머지·마이그레이션 §2·§5 (이슈 #15 Phase 2b-2)

구-포맷 감지 + one-way 승격(state→e2e_state, prd_state 신규 derive),
미지 컬럼·priority/비고·waiver 보존, 둘 다 covered만 제거. idempotent.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 리포트 2차원 + 메타데이터 동기화 (§6, frontmatter/intro/§1.1/제약)

**Files:**
- Modify: `skills/intent-distill/SKILL.md` (frontmatter ~line 3, intro ~line 9, §1.1 ~line 24, §6 ~line 73-86, 제약 ~line 115-121)

**Interfaces:**
- Consumes: §5 머지 결과.
- Produces: 2차원 리포트 + PRD를 반영한 스킬 설명/제약.

- [ ] **Step 1: §6 리포트를 2차원으로 교체한다**

§6 전체:

```markdown
## 6. 리포트

```
📊 의도 커버리지 동기화:
  신규 갭 {N}건 · 해소 {M}건 · triage(ambiguous/invalid) {K}건
  (파싱 실패 줄: {P}개)

열린 백로그 (상위):
  - [missing]  F007  someday 제외 — @feature:F007 스펙 없음
  - [partial]  F007  각 날만 집계 — e2e/specs/F007-progress.e2e.ts (이 시나리오 미커버)
  ...
```

머지 결과를 `docs/INTENT_BACKLOG.md`에 쓰고 변경을 보고한다.
```

→ 교체:

```markdown
## 6. 리포트 (2차원)

```
📊 의도 커버리지 동기화 (PRD · E2E):
  PRD: covered {a} · partial {b} · missing {c} · ambiguous {d} · blocked {e}
  E2E: covered {a} · partial {b} · missing {c} · ambiguous {d} · blocked {e}
  해소(둘 다 covered) {M}건 · 파싱 실패 줄 {P}개

⚠️ 비대칭 (서로 다른 행동 필요):
  - tested-but-unspecced (E2E≥covered & PRD=missing → PRD 작성): {목록}
  - specced-but-untested (PRD≥covered & E2E=missing → E2E 작성): {목록}

열린 백로그 (상위):
  - [prd:missing · e2e:covered]  F007  someday 제외 — PRD 미작성(작성 후보)
  - [prd:blocked · e2e:partial]  F012  ... — docs/product-specs 없음(보류)
  ...
```

`blocked`(substrate 부재 — 판정 불가)와 `missing`(substrate 있으나 미커버)을 **구분 표시**한다. 머지 결과를 `docs/INTENT_BACKLOG.md`에 쓰고 변경을 보고한다.
```

- [ ] **Step 2: frontmatter description + intro + §1.1 + 제약을 PRD 반영으로 갱신한다**

(a) frontmatter `description`(line 3) — `@feature E2E 실구조와 대조해` → `@feature PRD·E2E 실구조와 대조해`:
```yaml
description: "제품 의도 원장(.harness-intent.jsonl)을 @feature PRD·E2E 실구조와 대조해 2차원 커버리지 갭을 docs/INTENT_BACKLOG.md 영속 백로그로 동기화하는 스킬. '의도 정리', '의도 증류', '커버리지 분석', 'intent distill' 등을 요청할 때 사용한다."
```

(b) intro(line 9) — `각 의도가 @feature E2E로 커버되는지` → `각 의도가 @feature PRD·E2E로 커버되는지`. 동일 줄의 의미만 보존하며 PRD·E2E 2차원임을 명시.

(c) §1.1(line 24) — `(커버리지는 §4에서 실구조 파생)` 유지. 변경 불필요(이미 정확). 단 `필드: {... encoded}` 줄의 `encoded는 비권위라 읽지 않는다`는 그대로(2b-2도 미갱신).

(d) 제약 사항(line 117) — 첫 항목 끝에 PRD 차원 명시. `커버리지는 매 실행 실구조에서 파생한다` 줄을 `커버리지(PRD·E2E 2차원)는 매 실행 실구조에서 파생한다 — substrate 부재는 blocked로 미커버와 구분.`로 교체.

- [ ] **Step 3: 일관성 확인 + 커밋**

Run: `grep -n "PRD·E2E\|비대칭\|tested-but-unspecced\|2차원" skills/intent-distill/SKILL.md`
Expected: description·intro·§6·제약에 PRD·E2E 2차원 반영이 출력된다.

```bash
git add skills/intent-distill/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): intent-distill 2차원 리포트 + 메타 동기화 §6 (이슈 #15 Phase 2b-2)

리포트에 PRD/E2E 차원별 카운트 + 비대칭(tested-unspecced/specced-untested)
하이라이트 + blocked/missing 구분. description·intro·제약 PRD 반영.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: scaffold §7 capability + harness-cleanup B1 + §5.12.5

**Files:**
- Modify: `skills/harness-scaffold/SKILL.md` (§7 capability ~line 1434-1435, §5.12.5 ~line 854-859)
- Modify: `skills/harness-cleanup/SKILL.md` (B1 ~line 104)

**Interfaces:**
- Produces: derive 출시를 반영한 정직 capability 문구 + B1 PRD 차원 편입.

- [ ] **Step 1: §7 capability 두 줄을 갱신한다**

`skills/harness-scaffold/SKILL.md`의 의도 증류 줄(현재):
```
- 의도 증류 → "의도 정리"로 `.harness-intent.jsonl`을 @feature E2E와 대조해 `docs/INTENT_BACKLOG.md` 커버리지 백로그 동기화 (상세: intent-distill 스킬 — 플러그인 번들)
```
→ 교체:
```
- 의도 증류 → "의도 정리"로 `.harness-intent.jsonl`을 @feature PRD·E2E와 대조해 `docs/INTENT_BACKLOG.md` 2차원 커버리지 백로그 동기화 (상세: intent-distill 스킬 — 플러그인 번들)
```

PRD 명세 줄(현재, 끝 `커버리지 derive는 후속`):
```
- PRD 명세 → 새 feature 작업 시 `docs/product-specs/{id}-{slug}.md`에 `@feature:{id}`로 작성 (양식: docs/product-specs/_template.md · 상세: docs/product-specs/README.md) — always-on, 작성 관례·템플릿 제공(커버리지 derive는 후속)
```
→ 끝 괄호만 교체:
```
- PRD 명세 → 새 feature 작업 시 `docs/product-specs/{id}-{slug}.md`에 `@feature:{id}`로 작성 (양식: docs/product-specs/_template.md · 상세: docs/product-specs/README.md) — always-on, 작성 관례·템플릿 제공(의도↔PRD 커버리지는 "의도 정리"가 derive)
```

- [ ] **Step 2: harness-cleanup B1 줄에 PRD 차원을 추가한다**

`skills/harness-cleanup/SKILL.md` line 104(현재):
```
- `docs/INTENT_BACKLOG.md` 열린 백로그 검토 — 미커버 의도(missing/partial)를 `feature_list.json` 작업/E2E 스펙으로 승격 제안, invalid-feature/ambiguous는 triage. (동기화: "의도 정리" — intent-distill)
```
→ 교체:
```
- `docs/INTENT_BACKLOG.md` 열린 백로그 검토(2차원) — **tested-but-unspecced**(e2e covered·prd missing)는 PRD 작성, **specced-but-untested**(prd covered·e2e missing)는 E2E 스펙 작성으로 승격 제안, invalid-feature/ambiguous는 triage, blocked(substrate 부재)는 보류. (동기화: "의도 정리" — intent-distill)
```

- [ ] **Step 3: §5.12.5 INTENT_BACKLOG 생성 규칙 텍스트를 2차원 반영한다**

`skills/harness-scaffold/SKILL.md` §5.12.5의 distill 설명 줄(현재):
```
- `intent-distill` 스킬이 `.harness-intent.jsonl` ↔ `@feature` E2E 커버리지를 대조해 이 문서를 머지-싱크한다(미커버 갭 추가 / 커버됨 제거 / 사용자 주석·waiver 보존).
```
→ 교체:
```
- `intent-distill` 스킬이 `.harness-intent.jsonl` ↔ `@feature` PRD·E2E 2차원 커버리지를 대조해 이 문서를 머지-싱크한다(갭 추가 / 둘 다 covered 제거 / 사용자 주석·waiver 보존 / 구 E2E-only 백로그 one-way 승격).
```

- [ ] **Step 4: 확인 + 커밋**

Run: `grep -n "PRD·E2E\|tested-but-unspecced\|2차원 커버리지" skills/harness-scaffold/SKILL.md skills/harness-cleanup/SKILL.md`
Expected: §7 두 줄 + B1 + §5.12.5에 2차원 반영이 출력된다.

```bash
git add skills/harness-scaffold/SKILL.md skills/harness-cleanup/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): capability·B1·생성규칙 2차원 derive 반영 (이슈 #15 Phase 2b-2)

§7 의도 증류=PRD·E2E 2차원, PRD 명세 줄 derive 출시 반영. B1에 비대칭
승격(tested-unspecced→PRD / specced-untested→E2E). §5.12.5 동기화.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 버전 범프 1.26.0 → 1.27.0 + 트래킹

**Files:**
- Modify: `.claude-plugin/plugin.json`, `README.md`, `skills/harness-setup/references/project-context.md`, `.tracking/CHANGELOG.md`, `.tracking/HANDOFF.md`, `.tracking/TODO.md`

**Interfaces:**
- Consumes: Task 1~6 전체.
- Produces: 1.27.0 일관 버전 + 이력 + 핸드오프(2b-3 진입점).

- [ ] **Step 1: 버전 문자열을 1.27.0으로 올린다**

Run: `grep -rn "1\.26\.0" .claude-plugin/plugin.json README.md skills/harness-setup/references/project-context.md marketplace.json`
- `.claude-plugin/plugin.json` `version`, `README.md` 버전 줄, `project-context.md`(헤더·작업환경·버전 히스토리)를 `1.27.0`으로 갱신. `marketplace.json`에 version 필드가 있으면 갱신, 없으면 스킵(2b-1에서 없음 확인). manifest 스키마 **예시**("1.0.0")는 건드리지 않는다. "19개/24개 파일" 드리프트는 OUT OF SCOPE.

- [ ] **Step 2: project-context.md 설계 결정 + 버전 히스토리를 추가한다**

`skills/harness-setup/references/project-context.md` § 설계 결정에 2b-2(forward PRD derive·2차원 백로그·substrate≠missing·보수적·역방향 제외·skill-내부 마이그레이션) 한 항목, 버전 히스토리에 `1.27.0 — Intent→PRD Coverage Derive (Phase 2b-2, 이슈 #15)`.

- [ ] **Step 3: CHANGELOG 1.27.0 섹션을 추가한다**

`.tracking/CHANGELOG.md`에 기존 형식(`### 추가 (Added)`/`### 수정 (Changed)`)으로: intent-distill 2차원 derive(§3 게이팅·§4.1 PRD derive·§5 머지/마이그레이션·§6 리포트), INTENT_BACKLOG 2차원 헤더, §7 capability·B1·§5.12.5 동기화, 골든 픽스처 `test/intent-prd-coverage-fixtures.sh`, 멀티모델 자문(역방향 제외·5-상태+blocked·보수적 derive).

- [ ] **Step 4: HANDOFF + TODO를 갱신한다**

- `.tracking/HANDOFF.md`: 현재 버전 1.27.0, 이슈 #15 Phase 2b-2 종결(forward derive), P7 행에 2b-2 추가. **다음 작업 = Phase 2b-3**(정적 harness-check 검증: 빈섹션 경고·feature↔PRD 교차 derive·마커 검증·8-상태 taxonomy·doc-freshness 글로빙) + 잔여(역방향 "미검증 명세" 2b-4 후보·binding index·PRE-RED 게이트). 진입점 = spec §12. 날짜 절대화(2026-06-17).
- `.tracking/TODO.md`: Phase 2b-2 완료 체크, 2b-3/잔여 항목 신설.

- [ ] **Step 5: 일관성 + 회귀 확인 + 커밋**

Run: `grep -rn "1\.27\.0" .claude-plugin/plugin.json README.md | head` 그리고 `bash test/intent-prd-coverage-fixtures.sh && bash test/prd-substrate-fixtures.sh && bash test/run-fixtures.sh`
Expected: 버전 1.27.0 일관, 신규 픽스처 통과(exit 0), 기존 골든 픽스처(prd-substrate·structural) 회귀 통과.

```bash
git add .claude-plugin/plugin.json README.md skills/harness-setup/references/project-context.md .tracking/CHANGELOG.md .tracking/HANDOFF.md .tracking/TODO.md
git commit -m "$(cat <<'EOF'
chore(tracking): 1.27.0 범프 + 2b-2 트래킹 (이슈 #15 Phase 2b-2)

project-context 결정·버전 히스토리, CHANGELOG 1.27.0, plugin/README 버전,
HANDOFF(2b-3 진입점)·TODO.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**1. Spec coverage** (spec §4 구성요소 → task):
- §4.1 intent-distill §3 게이팅 → Task 2 ✅ · §4 derive → Task 3 ✅ · §5 머지/마이그레이션 → Task 4 ✅ · §6 리포트 → Task 5 ✅ · §2 구-포맷 감지 → Task 4 ✅
- §4.2 INTENT_BACKLOG 템플릿 헤더 → Task 1 ✅
- §4.3 scaffold §7 capability → Task 6 ✅
- §4.4 harness-cleanup B1 → Task 6 ✅
- §5 마이그레이션 → Task 4 ✅ · §9 버전 → Task 7 ✅ · §10 검증(픽스처) → Task 1 + Task 7 회귀 ✅

**2. Placeholder scan:** `prd_section_body` 추출기·바인딩 grep·헤더·리포트 포맷 모두 실제 내용 제공. "(가칭)"은 spec에서만; 플랜은 `test/intent-prd-coverage-fixtures.sh` 확정. §번호(~line N)는 anchor 힌트(현재 텍스트 verbatim 제공). 플레이스홀더 없음.

**3. Type/이름 일관성:**
- 상태값 `blocked:no-prd-substrate`/`blocked:no-e2e-substrate` — Task 2·3·4·5 동일 ✅
- 컬럼 `prd_state`/`e2e_state`/통합 `evidence`/`priority/비고` — Task 1(헤더)·4(머지)·5(리포트) 동일 ✅
- `prd_section_body` 추출기 — Global Constraints·Task 1 픽스처·Task 3 §4 **byte-identical** ✅
- 바인딩 `grep -Rl -Fx "@feature:{feature}" docs/product-specs/` — Task 1·3 동일(2b-1 규칙) ✅
- kind↔섹션(intended→behavior/acceptance, unintended→edge-cases/open-questions) — Task 3 ✅
- 마이그레이션 `state→e2e_state` — Task 4(§5)·spec D7 동일 ✅

이상 없음.
