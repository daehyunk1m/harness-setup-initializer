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

## 4. 커버리지 파생 (feature-범위, 증거 필수)

각 의도(intended+unintended)에 대해 5-상태를 산출한다:

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

## 5. 백로그 머지 (idempotent)

키 = 의도 `ts`. 각 의도:
- `covered` → 열린 백로그에 있으면 **제거**(해소).
- `missing` / `partial` / `ambiguous` / `invalid-feature` → 열린 백로그에 **없으면 추가**, 있으면 `state`/`evidence` **갱신**.
- **waiver 섹션에 키가 있으면 스킵**(재추가 안 함).

기존 행의 사용자 `priority/비고` 열은 키 매칭으로 **보존**(덮어쓰기 아닌 머지). waiver 섹션은 distill이 수정하지 않는다. → 같은 입력 = 같은 백로그(재실행 동일).

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
