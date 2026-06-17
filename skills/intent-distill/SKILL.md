---
name: intent-distill
description: "제품 의도 원장(.harness-intent.jsonl)을 @feature E2E 실구조와 대조해 커버리지 갭을 docs/INTENT_BACKLOG.md 영속 백로그로 동기화하는 스킬. '의도 정리', '의도 증류', '커버리지 분석', 'intent distill' 등을 요청할 때 사용한다."
allowed-tools: Bash(cat *) Bash(echo *) Bash(ls *) Bash(grep *)
---

# Intent Distill Skill

제품 의도(`.harness-intent.jsonl`, Phase 1 수집)를 읽어 각 의도가 `@feature` E2E로 커버되는지 **실구조에서 파생**하고, 미커버 갭을 `docs/INTENT_BACKLOG.md`(영속 백로그)에 **머지-싱크**한다. harness-feedback의 자매이나, 마찰의 이벤트-스트림 모델이 아니라 **지속 백로그 모델**이다 — 상태 파일(cursor) 없음, 백로그 문서가 durable 상태, 커버리지는 매 실행 derive(저장 flag 신뢰 안 함).

이 스킬은 **대상 프로젝트의 제품 의도**를 다룬다(하네스 자체가 아님) — gh 이슈는 현재 프로젝트 repo에 생성한다.

## 1. 의도 원장 읽기

```!
if [ -f .harness-intent.jsonl ]; then cat .harness-intent.jsonl; else echo "INTENT_LOG_NOT_FOUND"; fi
```

`INTENT_LOG_NOT_FOUND`이면 "`.harness-intent.jsonl`이 없습니다. 하네스가 셋업된 프로젝트에서 실행하세요." 출력 후 **종료**.

### 1.1 관용 파싱

- 빈 줄 무시. 각 줄을 JSON 파싱하되 **실패한 줄은 건너뛰고** 개수를 세어 리포트(§6)에 보고한다.
- 필드: `{ts, session, kind(intended|unintended), surface, feature, statement, encoded}`. **cursor 없음 — 전체 의도를 분석한다.** `encoded`는 **비권위라 읽지 않는다**(커버리지는 §4에서 실구조 파생).
- 유효 의도 0건이면 "기록된 의도가 없습니다." 출력 후 종료.

## 2. 백로그 읽기

```!
if [ -f docs/INTENT_BACKLOG.md ]; then cat docs/INTENT_BACKLOG.md; else echo "BACKLOG_NOT_FOUND"; fi
```

부재 시 빈 백로그(열린 백로그 0행, waiver 0행)로 시작한다. `## 열린 백로그` 표(키=ts)와 `## waiver` 표(키=ts)를 파싱하고, 사용자 `priority/비고` 열·waiver 항목을 **보존 대상**으로 기억한다.

**구-포맷 감지**: 헤더에 `prd_state`/`e2e_state`가 없고 단일 `state`/`evidence` 컬럼이면 2a(E2E-only) 백로그다 → §5 마이그레이션으로 승격한다. 헤더에 **모르는 추가 컬럼**이 있으면(사용자가 표를 확장) 그 컬럼과 값을 key=ts로 **그대로 보존**한다.

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

## 4. 커버리지 파생 (feature-범위, 증거 필수, 2차원)

각 의도(intended+unintended)에 대해 **`prd_state`와 `e2e_state`를 각각** 산출한다. 두 차원은 독립이며 substrate 부재는 `blocked:no-*-substrate`로 기록한다(미커버 `missing`과 절대 혼동 금지). E2E 차원은 §4.2, PRD 차원은 §4.1.

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

0. E2E substrate 부재(§3 E2E_ABSENT) → **`blocked:no-e2e-substrate`**. 아니면 아래 판정.
1. `feature`가 `""`이거나 `feature_list.json`에 없으면 → **`invalid-feature`** (증거: 사유 "feature 미지정/미존재"). 다음 의도로.
2. 해당 feature의 E2E 스펙을 **feature-범위로만** 찾는다(전체 E2E를 올리지 않는다):
   ```bash
   grep -rl "@feature:{feature}" e2e/specs/ 2>/dev/null
   ```
   매칭 스펙이 없으면 → **`missing`** (증거: feature_list 항목 + "@feature:{feature} 스펙 없음").
3. 매칭 스펙이 있으면 그 스펙 **파일만** 읽어 `statement`와 의미상 일치하는 시나리오(test/it 타이틀)를 판단:
   - 일치 시나리오 있음 → **`covered`** (증거: 스펙 경로 + 테스트 타이틀).
   - feature E2E는 있으나 이 statement 미커버 → **`partial`** (증거: 스펙 경로 + 미커버 요지).
   - 모호(statement 모호 / 매칭 불확실) → **`ambiguous`** (증거: 사유).

**모든 판정에 증거 필수** — 증거 없는 `covered`/`missing` 단정 금지.

(최적화: 백로그에 `covered` 증거로 이미 기록됐고 그 스펙 파일이 안 바뀐 의도는 재판정 스킵 가능.)

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

## 7. statement 이스케이프 (백로그·이슈 안전)

백로그 표 셀·gh 이슈 body에 statement를 넣을 때(Phase 1 ≤200 소독은 JSON 안전일 뿐):
- 파이프 `|` → `\|`, 줄바꿈(LF/CR) → 공백 한 칸.
- HTML 주석 delimiter 무력화: statement 내 `-->`·`<!--` → 공백 치환(fingerprint 주석 교란 차단).
- @mention 무력화: `@` → 코드 스팬(`` `@name` ``) 래핑 또는 zero-width 삽입.

## 8. gh 이슈 (항목별 옵트인)

백로그 항목을 사용자가 명시적으로 지시할 때만 생성한다(자동 생성 안 함):

```
백로그 항목을 GitHub Issue로 만들까요? (항목 번호 입력 / n=안 함)
```

선택 항목에 대해 — **현재 프로젝트 repo**에 생성(`--repo` 하드코딩 안 함):

```bash
gh issue create --label intent-gap \
  --title "[Intent] {feature}: {요약}" \
  --body "{§7로 이스케이프된 body}

<!-- intent-gap:fp={feature}:{ts} -->"
```

생성 직전 동일 `fp`의 열린 이슈를 조회해 있으면 "⚠️ 유사 열린 Issue #N — 중복일 수 있음" 힌트(하드 스킵 아님 — 사용자 판단). `gh` 미설치/실패 → 이슈만 스킵하고 백로그 sync는 정상 진행한다.

## 제약 사항

- 의도 원장(`.harness-intent.jsonl`)을 수정/삭제하지 않는다(읽기 전용; `encoded` 미갱신 — 비권위).
- 커버리지는 매 실행 실구조에서 파생한다(저장된 flag 신뢰 안 함). **증거 필수.**
- 백로그는 **머지**(덮어쓰기 아님) — 사용자 주석·waiver 보존. 키=`ts`라 재실행이 idempotent.
- gh 이슈는 **항목별 옵트인** + 사용자 확인. 백로그 sync는 gh-무관. 이슈 repo = 현재 프로젝트.
- harness-feedback(마찰 채널)과 **별개**다 — 통합하지 않는다.
