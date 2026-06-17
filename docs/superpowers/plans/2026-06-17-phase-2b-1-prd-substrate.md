# PRD Substrate (Phase 2b-1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `docs/product-specs/`를 빈 디렉토리에서 → feature별 PRD를 `@feature:{id}` whole-line 마커로 바인딩하는 구조화·스택비종속 substrate로 전환한다(2b-2 derive의 기반).

**Architecture:** 두 managed 정적 템플릿(`_template.md`·`README.md`)을 scaffold가 생성하고, always-on이라 기존 하네스엔 `[new]` 마이그레이션으로 소급 설치한다. 바인딩은 whole-line 리터럴 `@feature:{id}`(grep -Fx)로 E2E 프리미티브를 미러하되 위치 제약만 다르다. 파이프라인 게이트는 추가하지 않고(소프트 트리거=권고), capability는 정직하게 광고한다(derive는 2b-2).

**Tech Stack:** Markdown 템플릿, Bash(golden fixture + scaffold 생성 규칙), 두 SKILL.md 정규 사양(harness-scaffold=스캐폴딩, harness-setup=분석/§12.6.1 매핑).

## Global Constraints

- 버전: MINOR **1.25.0 → 1.26.0**.
- `feature_list.json` 스키마 **불변** · 신규 프로필 필드 **0** · 신규 `{{플레이스홀더}}` **0** · 두 SKILL.md 프로필 스키마 동일성 계약 유지.
- 바인딩 마커 = whole-line 리터럴 `@feature:{id}`, 발견 규칙 = `grep -Rl -Fx "@feature:{id}" docs/product-specs/`.
- `_template.md`·`README.md` = manifest category **`managed`**. 작성된 `{featureID}-{slug}.md` = **비-manifest-추적**(작성 E2E 스펙 동급, 업그레이드 미덮어쓰기).
- **always-on**(프로필 게이트 없음) · **파이프라인 동작 변경 0**(소프트 트리거는 권고이지 게이트·검증 주장 아님).
- capability 문구 정직: "PRD 작성 관례·템플릿 제공" — 의도↔PRD **derive는 2b-2**. "추적 가능"으로 광고 금지.
- 커밋 형식: `type(scope): 설명`(한국어, 첫 줄 ≤72자) + 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. 작업 브랜치 `feature/phase-2b-1-prd-substrate`(이미 생성됨).
- 별개 cleanup "19개 파일" 드리프트(핸드오프 §8)는 **OUT OF SCOPE** — 이 플랜은 정확한 카운트(harness-scaffold 기준 22)만 갱신한다.

---

### Task 1: PRD managed 템플릿 2종 + 골든 픽스처

**Files:**
- Create: `skills/harness-scaffold/templates/product-specs/_template.md`
- Create: `skills/harness-scaffold/templates/product-specs/README.md`
- Test: `test/prd-substrate-fixtures.sh`

**Interfaces:**
- Produces: 두 정적 템플릿 파일(플레이스홀더 0). `_template.md`은 `@feature:F000` 마커 + 5개 섹션 앵커(`<!-- harness:section=intent|behavior|edge-cases|acceptance|open-questions -->`) + Edge Cases anti-blank 가이드를 포함. 마커 발견 규칙 = `grep -Rl -Fx "@feature:{id}" docs/product-specs/`. 후속 Task들이 이 경로·카테고리·문구를 참조한다.

- [ ] **Step 1: 골든 픽스처를 먼저 작성한다**

`test/prd-substrate-fixtures.sh`:

```bash
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
{ grep -q "@feature:" "$T" 2>/dev/null && ok "@feature 마커 라인"; } || no "@feature 마커 없음"
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
```

- [ ] **Step 2: 픽스처를 실행해 실패를 확인한다**

Run: `chmod +x test/prd-substrate-fixtures.sh && bash test/prd-substrate-fixtures.sh`
Expected: FAIL — "_template.md 없음", "README.md 없음" 등으로 `FAIL>0`, exit 1.

- [ ] **Step 3: `_template.md`를 생성한다**

`skills/harness-scaffold/templates/product-specs/_template.md`:

```markdown
@feature:F000
<!-- ↑ 이 파일이 명세하는 feature_list.json의 id로 교체한다. 전체줄 리터럴(grep -Fx 매칭). 파일명 slug가 아니라 이 줄이 PRD↔feature 바인딩 권위다. -->

# {기능 제목}

<!-- harness:section=intent -->
## Intent / 의도
<!-- 이 기능이 왜 존재하는가 — 해결하는 사용자 문제. -->

<!-- harness:section=behavior -->
## Behavior / 동작 규칙
<!-- 사용자 관점 동작. feature_list.steps ↔ @feature E2E 시나리오와 1:1 매핑되게 적는다. -->

<!-- harness:section=edge-cases -->
## ⚠️ Edge Cases & Out-of-Scope / 제외·엣지케이스  (필수)
<!-- [필수] 이 기능이 다루지 않는 상황·제외 조건·무시할 입력을 명시한다.
     제외할 사항이 전혀 없다면 그 판단 근거와 함께 "명시적 제외 사항 없음"이라고 적는다.
     빈칸·TBD·N/A로 두지 않는다 — 명세 안 된 제외 규칙이 가장 흔한 버그 원천이다.
     예) "진행률은 각 날의 태스크만 집계 — someday는 제외" -->

<!-- harness:section=acceptance -->
## Acceptance / 수용 기준
<!-- 검증 가능한 기준. steps ↔ @feature E2E 시나리오로 확인 가능해야 한다. -->

<!-- harness:section=open-questions -->
## Open Questions / 미결
<!-- 아직 결정되지 않은 사항. 없으면 "없음". -->
```

- [ ] **Step 4: `README.md`를 생성한다**

`skills/harness-scaffold/templates/product-specs/README.md`:

```markdown
# 제품 명세 (Product Specs)

이 디렉토리는 각 feature의 **제품 요구사항 명세(PRD)**를 담는다. 의도·동작·제외 규칙을 산문으로 기록하는 곳이며, `feature_list.json`(기능 레지스트리)과 `@feature` E2E(회귀 가드)를 잇는 추적의 출력단이다.

## 작성 방법

1. `_template.md`를 복사해 `docs/product-specs/{featureID}-{slug}.md`로 만든다.
   - 예: feature `F007`의 진행률 차트 → `docs/product-specs/F007-progress-chart.md`
   - `{slug}`은 사람이 찾기 위한 힌트일 뿐 **바인딩 권위가 아니다**.
2. 파일에 `@feature:{featureID}` **전체줄**을 1개 넣는다(보통 상단). 이 줄이 PRD↔feature 바인딩 권위다.
   - 바인딩은 `grep -Rl -Fx "@feature:{id}" docs/product-specs/`로 발견된다(전체줄 리터럴 매칭 — 커스텀 ID 안전, 본문 예시 오탐 방지).
3. 각 섹션을 채운다. 특히 **⚠️ Edge Cases & Out-of-Scope**는 빈칸으로 두지 않는다 — 명세 안 된 제외 규칙이 가장 흔한 버그 원천이다.

## 기능 레지스트리

기능 목록의 권위는 `feature_list.json`이다. 각 PRD는 거기 등록된 feature 하나를 산문으로 명세한다. PRD 없는 feature가 있어도 정상이다(온디맨드 작성 — 작업 시점에 만든다).

## 운영 노트

- intent-distill("의도 정리")이 `docs/INTENT_BACKLOG.md`에 올린 `missing`/`partial` 항목은, 해당 feature의 PRD `Edge Cases`/`Acceptance` 섹션에 반영해 닫는다 — 의도→E2E 백로그와 의도→PRD 명세를 잇는 운영 규칙.
- 의도↔PRD 커버리지 자동 점검·미검증 명세 표면화는 후속 단계에서 배선된다(현재는 작성 관례·템플릿만 제공).
```

- [ ] **Step 5: 픽스처를 실행해 통과를 확인한다**

Run: `bash test/prd-substrate-fixtures.sh`
Expected: PASS — `FAIL=0`, "✅ 전부 통과", exit 0.

- [ ] **Step 6: 커밋**

```bash
git add skills/harness-scaffold/templates/product-specs/_template.md skills/harness-scaffold/templates/product-specs/README.md test/prd-substrate-fixtures.sh
git commit -m "$(cat <<'EOF'
feat(templates): PRD substrate 템플릿 2종 + 골든 픽스처 (이슈 #15 Phase 2b-1)

_template.md(섹션 앵커+anti-blank 가이드) · README.md(관례·마커 규칙).
whole-line @feature grep(-Fx) 견고성 픽스처 — 커스텀 ID·본문 오탐 검증.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: scaffold 생성 규칙 (§5 생성순서 + §5.12.6)

**Files:**
- Modify: `skills/harness-scaffold/SKILL.md` (생성순서 1번 ~line 201, §5.12.5 뒤 ~line 859)

**Interfaces:**
- Consumes: Task 1의 `templates/product-specs/{_template,README}.md`.
- Produces: scaffold가 빈 `docs/product-specs/` 대신 README+_template를 정적 복사 생성한다는 정규 사양. §6/§10.1/§7이 참조한다.

- [ ] **Step 1: 생성순서 1번을 수정한다**

`skills/harness-scaffold/SKILL.md` 생성순서 1번 블록(현재):

```
1. docs/ 디렉토리 구조 (빈 폴더):
   - `docs/product-specs/` — 제품 요구사항 문서
   - `docs/design-docs/` — 설계 결정 기록
   - `docs/exec-plans/` — 작업별 실행 계획
   - `docs/references/` — 참고 자료
```

→ 다음으로 교체:

```
1. docs/ 디렉토리 구조:
   - `docs/product-specs/` — 제품 요구사항 문서. **빈 폴더가 아니라** `README.md`(관례) + `_template.md`(양식)를 생성한다 (§ 5.12.6, managed)
   - `docs/design-docs/` — 설계 결정 기록 (빈 폴더)
   - `docs/exec-plans/` — 작업별 실행 계획 (빈 폴더)
   - `docs/references/` — 참고 자료 (빈 폴더)
```

- [ ] **Step 2: §5.12.6 생성 규칙 서브섹션을 추가한다**

`skills/harness-scaffold/SKILL.md`에서 §5.12.5(`docs/INTENT_BACKLOG.md 생성 규칙`) 블록의 끝(현재 `- intent-distill 미실행 시 빈 채로 남는다…` 줄 뒤, §5.13 헤딩 앞)에 삽입:

```markdown
### 5.12.6 docs/product-specs/ PRD substrate 생성 규칙

- `docs/product-specs/`에 두 managed 파일을 이 스킬의 템플릿에서 **그대로 복사**하여 생성한다 (플레이스홀더 없음 — INTENT_LEDGER.md와 동일한 정적 복사):
  - `templates/product-specs/README.md` → `docs/product-specs/README.md` (디렉토리 관례·마커 규칙·feature_list 진입점·운영 노트)
  - `templates/product-specs/_template.md` → `docs/product-specs/_template.md` (PRD 양식 — `@feature` 마커 + 섹션 앵커 주석 + Edge Cases anti-blank 가이드)
- **per-feature PRD stub은 생성하지 않는다** — PRD는 온디맨드(작업 시점)로 `_template.md`를 복사해 `docs/product-specs/{featureID}-{slug}.md`로 작성한다. 작성된 PRD는 사용자 소유 비-manifest-추적 파일이다(작성 E2E 스펙과 동급).
- **바인딩**: PRD↔feature는 PRD 파일 안의 whole-line 리터럴 `@feature:{id}` 1줄로 묶인다. 발견 규칙 = `grep -Rl -Fx "@feature:{id}" docs/product-specs/` (E2E `@feature` 태그와 규칙 대칭 — 위치만 제목→전체줄로 다름). 파일명 slug는 비권위 탐색 힌트다.
- **always-on**: 프로필 게이트 없이 무조건 생성한다. 두 파일은 manifest category `managed`(§ 5.13·§ 10.1), 작성 PRD는 미기록. 신규 플레이스홀더 0.
- 의도↔PRD 커버리지 derive·미검증 명세 표면화는 후속(2b-2)이다 — 2b-1은 substrate(관례·템플릿)만 제공한다.
```

- [ ] **Step 3: 일관성을 grep으로 확인한다**

Run: `grep -n "5.12.6\|product-specs.*README\|grep -Rl -Fx" skills/harness-scaffold/SKILL.md`
Expected: §5.12.6 헤딩 + README/_template 생성 줄 + 마커 grep 규칙이 출력된다. 생성순서 1번에 "빈 폴더가 아니라"가 보인다.

- [ ] **Step 4: 커밋**

```bash
git add skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): scaffold PRD substrate 생성 규칙 §5.12.6 (이슈 #15 Phase 2b-1)

생성순서 1번을 빈 product-specs → README+_template 생성으로 교체.
per-feature stub 없음(온디맨드), whole-line @feature 바인딩 규칙 명문화.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: manifest 카테고리 + 파일 분류 표 + 검증 + 파일 카운트 (§10.1, §6.2)

**Files:**
- Modify: `skills/harness-scaffold/SKILL.md` (§10.1 표 ~line 1552, §6.2 검증 ~line 1217, 파일 카운트 ~line 36)

**Interfaces:**
- Consumes: §5.12.6 (Task 2).
- Produces: 두 managed 파일이 §10.1 분류 표·§6.2 검증·정확한 파일 카운트에 반영된다.

- [ ] **Step 1: §10.1 파일별 분류 표에 두 행을 추가한다**

`skills/harness-scaffold/SKILL.md`에서 `| 22-f | \`docs/INTENT_BACKLOG.md\` | data |` 행 **뒤**에 삽입:

```
| 22-g | `docs/product-specs/README.md` | managed | PRD 디렉토리 관례 정적 문서(관례·마커 규칙·진입점). 템플릿 기반, 사용자 콘텐츠 없음 |
| 22-h | `docs/product-specs/_template.md` | managed | PRD 양식 정적 템플릿(섹션 앵커·anti-blank 가이드). 템플릿 기반. 작성된 `{id}-{slug}.md`는 사용자 소유 비기록(작성 E2E 스펙 동급) |
```

- [ ] **Step 2: §6.2 검증 라인에 product-specs 확인을 추가한다**

`skills/harness-scaffold/SKILL.md` §6.2 현재 라인:

```
# 6.2 docs/ 구조 확인 (HARNESS_FRICTION.md·INTENT_LEDGER.md 포함) + 마찰·의도 싱크 확인
ls -la docs/ docs/HARNESS_FRICTION.md docs/INTENT_LEDGER.md .harness-friction.jsonl .harness-intent.jsonl
```

→ 두 번째 줄을 다음으로 교체(끝에 product-specs substrate 추가):

```
ls -la docs/ docs/HARNESS_FRICTION.md docs/INTENT_LEDGER.md .harness-friction.jsonl .harness-intent.jsonl docs/product-specs/README.md docs/product-specs/_template.md
```

- [ ] **Step 3: 생성 파일 카운트를 갱신한다**

Run: `grep -rn "22개 파일\|22개\b\|생성.*22\|파일 22" skills/harness-scaffold/SKILL.md CLAUDE.md skills/harness-setup/SKILL.md`
- harness-scaffold/SKILL.md의 정확한 카운트(현재 22)를 **24**로 갱신한다 (README + _template = +2 managed 파일). 다른 곳의 "22개"도 같은 의미면 24로 동기화한다.
- `CLAUDE.md`·`harness-setup/SKILL.md`의 "19개 파일"은 **건드리지 않는다**(별개 드리프트, OUT OF SCOPE — 핸드오프 §8).

- [ ] **Step 4: 확인 + 커밋**

Run: `grep -n "22-g\|22-h\|product-specs/README.md\|product-specs/_template.md" skills/harness-scaffold/SKILL.md`
Expected: §10.1 두 행 + §6.2 검증 줄이 출력된다.

```bash
git add skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): PRD substrate manifest·검증·카운트 배선 (이슈 #15 Phase 2b-1)

§10.1 분류표에 README/_template(managed) 2행 + §6.2 검증 라인.
생성 파일 카운트 22→24. 작성 PRD는 비기록(사용자 소유).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: capability 카탈로그 + 렌더링 규칙 (§7) — 정직 문구

**Files:**
- Modify: `skills/harness-scaffold/SKILL.md` (§7 펜스드 블록 ~line 1424, 렌더링 규칙 ~line 1456)

**Interfaces:**
- Produces: 첫 셋업 보고에 PRD 작성 관례 능력 줄(always-on, derive=2b-2 명시).

- [ ] **Step 1: 카탈로그 펜스드 블록에 PRD 줄을 추가한다**

`skills/harness-scaffold/SKILL.md`에서 `- 의도 증류 → "의도 정리"로 …` 줄 **뒤**(즉 의도 증류 줄 다음)에 삽입:

```
- PRD 명세 → 새 feature 작업 시 `docs/product-specs/{id}-{slug}.md`에 `@feature:{id}`로 작성 (양식: docs/product-specs/_template.md · 상세: docs/product-specs/README.md) — always-on, 작성 관례·템플릿 제공(커버리지 derive는 후속)
```

- [ ] **Step 2: 렌더링 규칙에 PRD 줄 분류를 추가한다**

`skills/harness-scaffold/SKILL.md` §"이제 할 수 있는 일 카탈로그 렌더링 규칙"에서 `- **검증 게이트 · 자가진단 · 품질·부채 추적 · 마찰 자동 기록 · 의도 적재 줄**: 항상 생성되는 산출물이므로 무조건 렌더.` 줄을 다음으로 교체(PRD 명세 추가):

```
- **검증 게이트 · 자가진단 · 품질·부채 추적 · 마찰 자동 기록 · 의도 적재 · PRD 명세 줄**: 항상 생성되는 산출물이므로 무조건 렌더. PRD 명세 줄은 substrate(관례·템플릿)가 always-on 생성되므로 표시하되, **문구는 "작성 관례·템플릿 제공"에 한정**한다 — 의도↔PRD 커버리지 derive는 후속(2b-2)이라 "추적 가능"으로 광고하지 않는다(미와이어 능력 광고 불가).
```

- [ ] **Step 3: 확인 + 커밋**

Run: `grep -n "PRD 명세" skills/harness-scaffold/SKILL.md`
Expected: 카탈로그 줄 + 렌더링 규칙 줄 2곳 출력. "작성 관례·템플릿 제공" 문구 확인(과장 없음).

```bash
git add skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): Phase 4 능력 카탈로그에 PRD 명세 줄 (이슈 #15 Phase 2b-1)

always-on PRD 작성 관례·템플릿을 정직하게 광고 — derive는 2b-2.
렌더링 규칙에 순수 투영(미와이어 능력 광고 불가) 명시.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: coding-standards 관례 선언 + 소프트 트리거 (managed 템플릿)

**Files:**
- Modify: `skills/harness-scaffold/templates/rules/coding-standards.md` (검증 레벨 섹션 ~line 35 뒤)

**Interfaces:**
- Produces: 생성되는 하네스의 coding-standards에 PRD 작성 관례 + 소프트 트리거(권고, 게이트 아님). managed 템플릿이라 기존 하네스엔 §12.6 자동 감지로 전파.

- [ ] **Step 1: PRD 명세 섹션을 추가한다**

`skills/harness-scaffold/templates/rules/coding-standards.md`에서 `## E2E @critical 태그` 헤딩 **앞**(즉 검증 레벨 섹션의 jsdom 한계 줄 다음, E2E @critical 섹션 직전)에 삽입:

```markdown
## PRD 명세 (제품 요구사항)

- feature의 제품 요구사항은 `docs/product-specs/{featureID}-{slug}.md`에 산문으로 작성하고, 파일에 whole-line `@feature:{featureID}` 1줄을 넣어 feature와 바인딩한다(양식: `docs/product-specs/_template.md`, 상세: `docs/product-specs/README.md`).
- 특히 **Edge Cases & Out-of-Scope**(제외 규칙)를 빈칸으로 두지 않는다 — 명세 안 된 제외 규칙이 가장 흔한 버그 원천이다.
- **권고(게이트 아님)**: 새 `@feature` 작업을 시작할 때 `_template.md`를 복사해 PRD를 먼저 작성할 것을 권장한다. 이는 TDD 상태 게이트가 아니며 검증 주장도 아니다 — 작성 여부가 완료를 막지 않는다. 의도↔PRD 커버리지 점검은 후속 단계에서 배선된다.
```

- [ ] **Step 2: 확인 + 커밋**

Run: `grep -n "PRD 명세\|product-specs/_template\|권고(게이트 아님)" skills/harness-scaffold/templates/rules/coding-standards.md`
Expected: 새 섹션 + 소프트 트리거 줄 출력.

```bash
git add skills/harness-scaffold/templates/rules/coding-standards.md
git commit -m "$(cat <<'EOF'
feat(templates): coding-standards에 PRD 관례+소프트 트리거 (이슈 #15 Phase 2b-1)

PRD 작성 관례 선언 + 권고(게이트 아님 — 동작 변경 0).
managed라 기존 하네스엔 §12.6 자동 감지로 전파.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: §12.6.1 파일-템플릿 매핑 (harness-setup SKILL.md)

**Files:**
- Modify: `skills/harness-setup/SKILL.md` (§12.6.1 매핑 ~line 1136)

**Interfaces:**
- Produces: 두 managed 파일이 §12.6 자동 감지(템플릿 재렌더링 해시 비교) 대상이 되어, 향후 템플릿 변경이 기존 하네스에 전파된다.

- [ ] **Step 1: §12.6.1 매핑을 읽어 표 형식을 확인한다**

Run: `sed -n '1136,1162p' skills/harness-setup/SKILL.md`
Expected: `#### 12.6.1 파일-템플릿 매핑` 표(파일 → 템플릿 경로 → 플레이스홀더) 확인. 정적 managed 파일(예: INTENT_LEDGER.md, e2e/README.md)이 "플레이스홀더 없음"으로 등재된 형식을 파악한다.

- [ ] **Step 2: 두 매핑 행을 추가한다**

매핑 표에서 정적 managed 파일 행들(예: `docs/INTENT_LEDGER.md` 또는 `e2e/README.md`) 근처에, 표의 컬럼 형식에 맞춰 두 행을 추가한다. INTENT_LEDGER.md 행이 `| docs/INTENT_LEDGER.md | templates/INTENT_LEDGER.md | 없음 |` 형식이면 동형으로:

```
| docs/product-specs/README.md | templates/product-specs/README.md | 없음 |
| docs/product-specs/_template.md | templates/product-specs/_template.md | 없음 |
```

(실제 컬럼 헤더·구분자에 맞춘다. 매핑이 표가 아니라 목록 형식이면 같은 목록 항목 형식으로 추가한다.)

- [ ] **Step 3: 확인 + 커밋**

Run: `grep -n "product-specs/README.md\|product-specs/_template.md" skills/harness-setup/SKILL.md`
Expected: §12.6.1에 두 매핑 행 출력.

```bash
git add skills/harness-setup/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): §12.6.1 매핑에 PRD substrate 2파일 (이슈 #15 Phase 2b-1)

README/_template를 자동 감지 대상으로 등재 — 향후 템플릿 변경 전파.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 마이그레이션 M-1.25.0-to-1.26.0 ([new] 소급 설치)

**Files:**
- Modify: `skills/harness-scaffold/SKILL.md` (§10.3 레지스트리 ~line 1828 뒤, "이후 불필요" 노트 ~line 1847)

**Interfaces:**
- Consumes: §10.1 카테고리(Task 3), §5.12.6 생성 규칙(Task 2).
- Produces: 기존 하네스(≤1.25.0) 업그레이드 시 두 managed 파일이 `[new]`로 소급 설치된다(idempotent, 사용자 파일 보존). always-on 기능이라 필수.

- [ ] **Step 1: M-1.6.4-to-1.7.0 다음(최신 등록 마이그레이션 뒤)에 신규 엔트리를 추가한다**

`skills/harness-scaffold/SKILL.md`에서 마지막 등록 마이그레이션 블록 뒤, `> 새 버전을 추가할 때 마이그레이션이 필요한지…` 노트 **앞**에 삽입:

```markdown
#### M-1.25.0-to-1.26.0: PRD substrate 소급 설치

**조건**: harness.version == "1.25.0"
**결과**: harness.version → "1.26.0"

> PRD substrate는 **always-on**이라(옵트인 아님) 기존 하네스에도 소급 설치한다. e2e/README(옵트인이라 소급 안 함)와 대비 — always-on 기능을 소급 안 하면 "1.26.0인데 substrate 없음" 계약 불일치가 생긴다.

**변경 목록**:

1. [new] docs/product-specs/README.md: PRD 디렉토리 관례 문서
   - 카테고리: managed
   - 템플릿: templates/product-specs/README.md (플레이스홀더 없음, 정적 복사)
   - **멱등·보존**: 파일이 이미 있으면 덮어쓰지 않고 skip + 보고(사용자 작성 보존)

2. [new] docs/product-specs/_template.md: PRD 양식 템플릿
   - 카테고리: managed
   - 템플릿: templates/product-specs/_template.md (플레이스홀더 없음, 정적 복사)
   - **멱등·보존**: 파일이 이미 있으면 덮어쓰지 않고 skip + 보고

> 두 파일은 [new]라 §12.6 자동 감지가 아니라 이 마이그레이션으로 생성된다(자동 감지는 기존 manifest 파일 업데이트 전용). 생성 후 manifest files에 category `managed`로 등록한다(§10.1 22-g·22-h). coding-standards.md의 PRD 관례 섹션 추가는 managed 템플릿 변경이라 §12.6 자동 감지로 전파(별도 항목 불필요).
```

- [ ] **Step 2: "이후 불필요" 노트가 1.26.0을 잘못 포함하지 않게 정리한다**

`skills/harness-scaffold/SKILL.md`에서 `> 새 버전을 추가할 때 마이그레이션이 필요한지 판단 기준: …` 노트를 확인한다. 1.9.0~1.25.0 무마이그레이션 노트가 있으면 그 범위는 유지하고, 1.26.0이 `[new]` 파일로 마이그레이션을 **가진다**는 점이 위 신규 엔트리로 명확하면 충분하다. 노트에 "1.26.0도 불필요" 같은 잘못된 일반화가 없는지 grep으로 확인한다.

Run: `grep -n "1.26.0\|이후.*마이그레이션 불필요\|1.9.0 ~\|1.25.0" skills/harness-scaffold/SKILL.md`
Expected: M-1.25.0-to-1.26.0 엔트리가 보이고, 1.26.0을 "불필요"로 분류한 노트가 없다.

- [ ] **Step 3: 커밋**

```bash
git add skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): M-1.25.0-to-1.26.0 PRD substrate 소급 마이그레이션 (이슈 #15 Phase 2b-1)

always-on이라 기존 하네스에 README/_template [new] 소급 설치.
idempotent·skip-if-exists(사용자 파일 보존). 계약 불일치 방지.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: harness-check.sh 구조 검사 + checklist 동기화

**Files:**
- Modify: `skills/harness-scaffold/templates/harness-check.sh` (① 필수 파일 ~line 20-34)
- Modify: `skills/harness-setup/references/harness-checklist.md` (§1.1 ~line 27, §8 ~line 216)

**Interfaces:**
- Consumes: §5.12.6 생성 규칙.
- Produces: harness-check ①이 managed substrate(README+_template) 존재를 구조 검사(부재=실패); 작성 PRD 부재는 보류. checklist §1.1/§8 동기.

- [ ] **Step 1: harness-check.sh ① 필수 파일에 product-specs substrate를 추가한다**

`skills/harness-scaffold/templates/harness-check.sh` ① 블록을 읽는다: `Run: sed -n '18,40p' skills/harness-scaffold/templates/harness-check.sh`. `docs/` 존재 확인 직후, 같은 패턴(존재→✅ / 부재→❌ + 실패 마킹)으로 두 파일 검사를 추가한다. 기존 docs/ 검사가 다음 형식이면:

```bash
if [ -d docs ]; then echo "✅ docs/"; else echo "❌ docs/ 없음"; FAIL=1; fi
```

그 뒤에 추가(변수명·실패 마킹은 스크립트의 기존 관례에 맞춘다):

```bash
if [ -f docs/product-specs/README.md ] && [ -f docs/product-specs/_template.md ]; then
  echo "✅ docs/product-specs/ substrate (README·_template)"
else
  echo "❌ docs/product-specs/ substrate 없음 (README·_template)"; FAIL=1
fi
# 작성된 PRD({id}-{slug}.md) 부재는 실패가 아니라 보류 — 새 프로젝트는 PRD 0개가 정상
if ls docs/product-specs/[!_]*.md >/dev/null 2>&1; then
  echo "✅ 작성된 PRD 존재"
else
  echo "⏸️ 작성된 PRD 없음 — 보류(온디맨드 작성, 실패 아님)"
fi
```

- [ ] **Step 2: checklist §1.1·§8을 동기화한다**

`skills/harness-setup/references/harness-checklist.md`:
- §1.1(필수 파일 존재 ~line 27)에 `docs/product-specs/README.md`·`docs/product-specs/_template.md`를 필수 substrate로 추가하고, 작성된 PRD(`{id}-{slug}.md`) 부재는 **보류**(E2E "판정 보류"·Q2 미강제와 평행)라고 한 줄 명시한다.
- §8(빠른 자가진단 ~line 216)의 `# 1. 필수 파일` 목록에 두 파일을 추가한다(harness-check.sh ①과 동일 SSoT).

Run: `sed -n '25,35p;216,230p' skills/harness-setup/references/harness-checklist.md` 로 현재 형식을 확인한 뒤 동형으로 편집한다.

- [ ] **Step 3: 확인 + 커밋**

Run: `grep -n "product-specs" skills/harness-scaffold/templates/harness-check.sh skills/harness-setup/references/harness-checklist.md`
Expected: harness-check.sh ① 검사 + 보류 분기, checklist §1.1·§8에 두 파일.

```bash
git add skills/harness-scaffold/templates/harness-check.sh skills/harness-setup/references/harness-checklist.md
git commit -m "$(cat <<'EOF'
feat(templates): harness-check PRD substrate 구조 검사 (이슈 #15 Phase 2b-1)

① 필수 파일에 README/_template(부재=실패) + 작성 PRD 부재=보류.
checklist §1.1·§8 동기(SSoT). E2E 판정 보류 패턴 미러.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: 버전 범프 1.25.0 → 1.26.0 + 트래킹

**Files:**
- Modify: `skills/harness-setup/references/project-context.md`, `.tracking/CHANGELOG.md`, `.claude-plugin/plugin.json`, `marketplace.json`, `README.md`, `.tracking/HANDOFF.md`, `.tracking/TODO.md`

**Interfaces:**
- Consumes: Task 1~8 전체.
- Produces: 1.26.0 일관 버전 + 변경 이력 + 핸드오프(2b-2 fast-follow 진입점).

- [ ] **Step 1: 버전 문자열을 모두 1.26.0으로 올린다**

Run: `grep -rn "1\.25\.0" .claude-plugin/plugin.json marketplace.json README.md skills/harness-setup/references/project-context.md`
- `.claude-plugin/plugin.json`·`marketplace.json`의 `version`·스킬 버전 줄, `README.md` 버전 줄을 `1.26.0`으로 갱신한다. (스킬 번들 카운트는 변동 없음 — 신규 스킬 아님.)
- 두 SKILL.md 프로필 스키마의 version 필드가 있으면(manifest 스키마 예시는 1.0.0 고정 예시이므로 변경하지 않는다) — 실제 버전 SSoT는 plugin.json·project-context. 변경 대상만 올린다.

- [ ] **Step 2: project-context.md에 설계 결정·버전 히스토리를 추가한다**

`skills/harness-setup/references/project-context.md` § 설계 결정 사항에 PRD substrate 결정(per-feature 파일·whole-line @feature·always-on 소급 마이그레이션·정직 capability·소프트 트리거·derive는 2b-2)을 한 항목으로 추가하고, 버전 히스토리에 `1.26.0 — PRD substrate (Phase 2b-1, 이슈 #15)`를 추가한다.

- [ ] **Step 3: CHANGELOG.md에 1.26.0 엔트리를 추가한다**

`.tracking/CHANGELOG.md`에 기존 형식(`### 추가 (Added)` 등)으로:
- 추가: PRD substrate(`templates/product-specs/{README,_template}.md` managed), §5.12.6 생성 규칙, §10.1 카테고리 22-g/22-h, §7 PRD 능력 줄, coding-standards PRD 관례+소프트 트리거, §12.6.1 매핑, M-1.25.0-to-1.26.0 [new] 소급 마이그레이션, harness-check ① substrate 검사, 골든 픽스처 `test/prd-substrate-fixtures.sh`.
- 멀티모델 자문 2회 반영(H1~H7) 한 줄.

- [ ] **Step 4: HANDOFF.md·TODO.md를 갱신한다**

- `.tracking/HANDOFF.md`: 현재 버전 1.26.0, 이슈 #15 Phase 2b-1 종결(2b-2 미착수), P-커버리지 P2/P7 등 해당 줄에 PRD substrate 추가. **다음 작업 = Phase 2b-2 fast-follow**(intent-distill PRD 방향 derive·미검증 명세·빈섹션/마커 검증·8-상태 taxonomy·doc-freshness 글로빙·binding index) — 진입점·앵커 명시.
- `.tracking/TODO.md`: Phase 2b-1 항목 완료 체크, 2b-2 항목 신설(spec §11 비-스코프를 작업 목록으로 이월).

- [ ] **Step 5: 일관성 확인 + 커밋**

Run: `grep -rn "1\.26\.0" .claude-plugin/plugin.json marketplace.json README.md skills/harness-setup/references/project-context.md | head` 그리고 `bash test/prd-substrate-fixtures.sh && bash test/run-fixtures.sh`
Expected: 버전 1.26.0 일관, PRD 픽스처 통과(exit 0), 기존 골든 픽스처(structural-test) 회귀 통과.

```bash
git add skills/harness-setup/references/project-context.md .tracking/CHANGELOG.md .claude-plugin/plugin.json marketplace.json README.md .tracking/HANDOFF.md .tracking/TODO.md
git commit -m "$(cat <<'EOF'
chore(tracking): 1.26.0 범프 + PRD substrate 트래킹 (이슈 #15 Phase 2b-1)

project-context 설계 결정·버전 히스토리, CHANGELOG 1.26.0,
plugin/marketplace/README 버전, HANDOFF(2b-2 fast-follow 진입점)·TODO.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**1. Spec coverage** (spec §4 구성요소 → task):
- §4.1 `_template.md` → Task 1 ✅
- §4.2 `README.md` → Task 1 ✅
- §4.3 scaffold(§5 생성순서/§5.12.x/§5.13 manifest/§6 검증/§7 capability/§10.2·§12.6.1 매핑) → Task 2(생성순서·§5.12.6), Task 3(§5.13·§10.1·§6.2·카운트), Task 4(§7), Task 6(§12.6.1) ✅
- §4.4 coding-standards 관례+소프트 트리거 → Task 5 ✅
- §4.5 마이그레이션 M-1.25.0-to-1.26.0 [new] → Task 7 ✅
- §4.6 harness-check/checklist → Task 8 ✅
- §9 버전/마이그레이션, §10 수용기준 → Task 9(범프) + 전 Task에 분산 ✅
- §8 검증(픽스처) → Task 1(픽스처) + Task 9 Step 5(회귀) ✅

**2. Placeholder scan:** 각 편집 Task는 실제 삽입 텍스트(코드블록)를 제공. Task 6은 표 컬럼 형식 확인 후 동형 추가(현재 표 형식을 sed로 읽는 단계 포함) — "find the anchor + 동형 추가"는 플레이스홀더가 아니라 형식-적응 지시(실제 두 행 내용은 명시됨). OK.

**3. Type/이름 일관성:**
- 경로 `skills/harness-scaffold/templates/product-specs/{_template,README}.md` — Task 1·2·6·7 전부 동일 ✅
- 생성 경로 `docs/product-specs/{README,_template}.md` — Task 2·3·6·7·8 동일 ✅
- 마커 규칙 `grep -Rl -Fx "@feature:{id}" docs/product-specs/` — 픽스처·README·§5.12.6·coding-standards 동일 ✅
- 카테고리 `managed`(템플릿) / 비기록(작성 PRD) — Task 3·7·8 일관 ✅
- 섹션 앵커 `harness:section=intent|behavior|edge-cases|acceptance|open-questions` — _template(Task 1)·픽스처(Task 1) 동일 5개 ✅
- 마이그레이션 ID `M-1.25.0-to-1.26.0` — Task 7·9 동일 ✅

이상 없음.
