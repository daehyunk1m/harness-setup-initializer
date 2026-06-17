# Intent Ledger — Phase 1 수집 인프라 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** friction의 자매 채널로, 세션 종료 시 제품 의도(intended/unintended)를 `.harness-intent.jsonl`에 증류 적재하는 수집 인프라를 하네스 스킬에 추가한다.

**Architecture:** 이 작업은 **하네스 스킬 소스(템플릿/사양 markdown) 편집**이지 런타임 코드 작성이 아니다. 따라서 테스트 사이클은 grep 기반 검증 + 골든 픽스처 회귀(`test/run-fixtures.sh`) + 3-파일 스키마 정합성 교차검증으로 구성된다(CLAUDE.md "정합성 검사" 모델). friction 채널(`.harness-friction.jsonl` → harness-feedback)의 저수준 기계(SESSION_ID·소독·append·`data` 카테고리·git 전략)를 의도적으로 동일하게 미러링한다.

**Tech Stack:** Markdown 템플릿/사양 (`SKILL.md`, `templates/rules/*.md`, `templates/*.md`), bash 자가진단 스크립트, JSON Lines 싱크. 검증: `grep`, `bash test/run-fixtures.sh`.

## Global Constraints

스펙(`docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md`)의 프로젝트 전역 요구 — 모든 태스크에 암묵 적용:

- **불변 스키마 계약**: `{ts, session, kind, surface, feature, statement, encoded:{prd,e2e,test}}` — **세 곳(INTENT_LEDGER.md · session-routine § 의도 로그 · scaffold §5.12.4)에서 글자 그대로 동일**해야 한다.
- **statement**: ≤200자. 소독 규칙은 friction 상속 — 큰따옴표 `"`→작은따옴표 `'`, 개행(LF/CR)→공백, 백슬래시 `\` 제거, 200자 초과 절단.
- **encoded**: Phase 1에서 **항상** `{"prd":false,"e2e":false,"test":false}`.
- **always-on**: 프로필 플래그 없음. 신규 프로필 필드 **0**, 신규 `{{...}}` 플레이스홀더 **0**.
- **싱크**: `.harness-intent.jsonl` (프로젝트 루트, manifest category `data`, git 추적·`.gitignore` 미추가). **정적 참조 doc**: `docs/INTENT_LEDGER.md` (manifest category `managed`).
- **SESSION_ID**: friction과 **동일 값 공유** (claude-progress.txt `SESSION_ID:`, session-routine Step 1.5).
- **능력 게이팅**: §7 카탈로그는 *수집만* 광고한다 — 증류·PRD/E2E 승격은 미배선이므로 광고 금지(미와이어 능력 광고 불가).
- **버전**: `1.23.0` → `1.24.0` (MINOR).
- **비-스코프**: distill 스킬·PRD diff·E2E 백로그·`encoded` 갱신·cursor·추적 리포트는 Phase 2 (건드리지 않음).

## File Structure

**생성 (1개):**
- `skills/harness-scaffold/templates/INTENT_LEDGER.md` — 의도 레코드 스키마/`kind`/`surface`/friction-경계 정적 참조표 (HARNESS_FRICTION.md 미러).

**수정:**
- `skills/harness-scaffold/templates/rules/session-routine.md` — § 세션 종료 Step 4.2 적재 + 신규 § 의도 로그(§ 마찰 로그 미러).
- `skills/harness-scaffold/SKILL.md` — §5 생성순서(17-d/17-e)·파일 수(line 36)·§5.12.3/5.12.4 생성규칙·§5.13 manifest(line 926)·§10.1 분류표·§5.7 doc-freshness 제외·§6.2 검증 ls·§7 능력 카탈로그.
- `skills/harness-scaffold/templates/harness-check.sh` — 필수 파일 체크 루프에 싱크 추가.
- `skills/harness-setup/references/harness-checklist.md` — 싱크 체크리스트 항목 + 검증 ls.
- 버전: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`, `skills/harness-setup/references/project-context.md`.
- 트래킹: `.tracking/CHANGELOG.md`, `.tracking/HANDOFF.md`, `.tracking/TODO.md`.

> **참고**: `harness-scaffold/references`는 `../harness-setup/references` 심링크다(SSoT 단일본). harness-checklist.md·project-context.md는 한 번만 수정하면 양쪽에 반영된다.

---

### Task 1: INTENT_LEDGER.md 정적 참조 문서

**Files:**
- Create: `skills/harness-scaffold/templates/INTENT_LEDGER.md`

**Interfaces:**
- Produces: 의도 레코드 스키마의 정본 참조표. Task 2(§ 의도 로그)·Task 3(§5.12.4)이 **동일 스키마**를 반복하므로, 여기서 확정한 7-필드·`kind` enum·소독 규칙이 그 둘과 글자 그대로 일치해야 한다(Global Constraints 불변 스키마).

- [ ] **Step 1: 파일 생성 (전체 내용)**

`skills/harness-scaffold/templates/INTENT_LEDGER.md`에 아래를 그대로 작성한다:

````markdown
# 하네스 의도 원장 (Intent Ledger)

> 이 파일은 제품 의도(intended/unintended) 레코드의 **스키마/유형 참조표**다 (정적 문서).
> 실제 의도는 프로젝트 루트의 `.harness-intent.jsonl`에 한 줄씩 기록되며(세션 종료 시 오케스트레이터가 증류 적재),
> 누적된 원장은 추후 PRD 반영·E2E 스펙 근거로 증류한다(Phase 2 — 미배선).
>
> 자매 채널: `.harness-friction.jsonl`(프로세스 마찰) ↔ 이 원장(제품 의도). 같은 인프라, 다른 페이로드.

## kind 유형

| kind | 의미 | 예 |
|------|------|----|
| `intended` | 사용자가 원하는 동작 진술 | "진행률은 각 날의 태스크만 집계한다" |
| `unintended` | 사용자가 관찰한 오작동 | "파이차트에 someday가 섞인다" |

## friction 채널과의 경계

`.harness-intent.jsonl`(제품 의도)과 `.harness-friction.jsonl`(프로세스 마찰)은 **직교**한다:

| 채널 | 기록 대상 | 예 |
|------|----------|----|
| 마찰(`.harness-friction.jsonl`) | TDD 기계가 저항한 **프로세스** 사건 | Implementer 재시도, Reviewer NEEDS_FIX, E2E FAIL, 리팩터 롤백 |
| 의도(`.harness-intent.jsonl`) | 제품이 무엇을 해야 하는지에 대한 **제품** 진술 | "각 날만 집계", "someday 제외", "버튼이 두 번 눌린다" |

한 버그가 둘 다 유발하면 각 채널이 각자의 면을 기록한다(중복 아님 — 다른 싱크·다른 분석기). 제품 버그는 프로세스 마찰 0으로 통과할 수 있다(유닛 통과·재시도 0). 그래서 별도 채널이 필요하다.

## 스키마 (한 줄 = 1 의도, JSON Lines)

```json
{"ts":"2026-06-17T04:30:00Z","session":"2026-06-17T04-12-03Z-a3f9","kind":"intended","surface":"progress","feature":"F007","statement":"진행률 파이차트는 각 날의 태스크만 집계하고 someday는 제외한다","encoded":{"prd":false,"e2e":false,"test":false}}
```

| 필드 | 의미 |
|------|------|
| `ts` | 적재 시각 (ISO8601 UTC) |
| `session` | 세션 고유 ID (`{ISO 시각}-{4자 난수}`) — 마찰 로그와 **동일 값 공유** |
| `kind` | `intended` \| `unintended` |
| `surface` | 영역 태그 (소문자-kebab, 예: `progress`, `section-expand`) — 증류 grouping용 |
| `feature` | 관련 feature ID 또는 `""` |
| `statement` | 소독된 의도 한 줄 (≤200자) |
| `encoded` | `{prd, e2e, test}` 승격 상태 — **현재 항상 all-false**. Phase 2 증류가 채운다 |

오케스트레이터(`.claude/rules/session-routine.md § 의도 로그` 참조)가 세션 종료 시 그 세션의 `claude-progress.txt` `요구:` 줄 + 오작동 발화를 증류해 append한다. 의도 발화가 없는 세션은 0줄(정상).

## 증류 (Phase 2 — 예정, 미배선)

누적된 `.harness-intent.jsonl`은 추후:
- `intended` 의도 → PRD 해당 섹션 반영
- E2E 미커버 `intended` → "스펙 작성 후보"로 목록화
- `unintended` → "왜 이 의도가 명세에 없었나" 역추적 → PRD 보강

> 이 증류 단계와 `encoded` 갱신은 아직 배선되지 않았다 (Phase 2). 현재는 **수집만** 한다.
````

- [ ] **Step 2: 생성·정합성 검증**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
test -f skills/harness-scaffold/templates/INTENT_LEDGER.md && echo "EXISTS"
grep -c '{{' skills/harness-scaffold/templates/INTENT_LEDGER.md
grep -oE '"(ts|session|kind|surface|feature|statement|encoded)"' skills/harness-scaffold/templates/INTENT_LEDGER.md | sort -u | tr '\n' ' '; echo
grep -q 'intended' skills/harness-scaffold/templates/INTENT_LEDGER.md && grep -q 'unintended' skills/harness-scaffold/templates/INTENT_LEDGER.md && grep -q '직교' skills/harness-scaffold/templates/INTENT_LEDGER.md && echo "KIND+BOUNDARY OK"
```
Expected:
```
EXISTS
0
"encoded" "feature" "kind" "session" "statement" "surface" "ts"
KIND+BOUNDARY OK
```
(플레이스홀더 0, 7-필드 모두 존재, kind enum + friction 경계 존재.)

- [ ] **Step 3: 커밋**

```bash
git add skills/harness-scaffold/templates/INTENT_LEDGER.md
git commit -m "$(cat <<'EOF'
feat(templates): INTENT_LEDGER.md 의도 원장 정적 참조 문서 (이슈 #15)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: session-routine — § 의도 로그 + 세션 종료 Step 4.2

**Files:**
- Modify: `skills/harness-scaffold/templates/rules/session-routine.md` (§ 세션 종료 코드블록 line 310–314; 파일 끝 § 마찰 로그 다음 line 421)

**Interfaces:**
- Consumes: Task 1이 확정한 7-필드 스키마 + 소독 규칙. 여기 § 의도 로그의 필드표·소독 규칙은 INTENT_LEDGER.md와 **글자 그대로 동일**해야 한다.
- Produces: 오케스트레이터의 세션 종료 적재 행동 정본. Task 3·4의 prose가 이 § 의도 로그를 가리킨다.

- [ ] **Step 1: § 세션 종료 코드블록에 Step 4.2 삽입**

현재 (line 310–314):
```
4. 진행 중인 TDD 사이클이 있으면:
   - TDD STATE 블록 저장
   - 마찰 이벤트 기록(session-incomplete) — § 마찰 로그 참조(.harness-friction.jsonl에 append)
     (사이클 미완료로 종료될 때의 안전망 기록 — 종료 시점에 반드시 1줄 append)
4.5 피드백 보고 트리거 — cursor 이후 미보고 마찰을 평가해 충족 시 한 줄 제안 (§ 피드백 보고 트리거)
```

`4.5 피드백 보고 트리거` 줄 **바로 앞**에 다음 한 줄을 삽입한다:
```
4.2 의도 적재 — 이 세션의 `claude-progress.txt` `요구:` 줄 + 오작동 발화를 의도 줄로 증류해 `.harness-intent.jsonl`에 append (§ 의도 로그). 의도 발화 없으면 0줄(정상)
```

삽입 후 블록:
```
4. 진행 중인 TDD 사이클이 있으면:
   - TDD STATE 블록 저장
   - 마찰 이벤트 기록(session-incomplete) — § 마찰 로그 참조(.harness-friction.jsonl에 append)
     (사이클 미완료로 종료될 때의 안전망 기록 — 종료 시점에 반드시 1줄 append)
4.2 의도 적재 — 이 세션의 `claude-progress.txt` `요구:` 줄 + 오작동 발화를 의도 줄로 증류해 `.harness-intent.jsonl`에 append (§ 의도 로그). 의도 발화 없으면 0줄(정상)
4.5 피드백 보고 트리거 — cursor 이후 미보고 마찰을 평가해 충족 시 한 줄 제안 (§ 피드백 보고 트리거)
```

- [ ] **Step 2: 파일 끝(§ 마찰 로그 다음)에 § 의도 로그 추가**

`session-routine.md` 맨 끝(현재 line 421 `- 보고 상태는 ...` 다음 줄)에 아래를 추가한다:

````markdown

---

## 의도 로그

세션 종료 시(§ 세션 종료 Step 4.2) 이 세션의 제품 의도·오작동 발화를 `.harness-intent.jsonl`(프로젝트 루트, append-only)에 **소독된 JSON 한 줄씩 append**한다. 입력은 `claude-progress.txt`의 `요구:` 줄 + 사용자의 오작동 설명이다(파생이지 중복작성 아님). 누적된 원장은 추후 PRD·E2E 근거로 증류한다(Phase 2 — 미배선).

**기록 방법** — 한 줄을 그대로 append한다(`>>`):
```
echo '{"ts":"2026-06-17T04:30:00Z","session":"<SESSION_ID>","kind":"intended","surface":"progress","feature":"F007","statement":"<소독된 의도 한 줄>","encoded":{"prd":false,"e2e":false,"test":false}}' >> .harness-intent.jsonl
```

**필드** (한 줄 = 1 의도):
| 필드 | 값 |
|------|------|
| `ts` | 적재 시각, ISO8601 UTC |
| `session` | § 세션 시작 Step 1.5의 SESSION_ID (마찰 로그와 **동일 값**) |
| `kind` | `intended`(원하는 동작) \| `unintended`(오작동 관찰) |
| `surface` | 영역 태그 (소문자-kebab, 예: `progress`) — 증류 grouping용 |
| `feature` | 관련 feature ID, 없으면 `""` |
| `statement` | 소독된 의도 한 줄 (아래 소독 규칙, ≤200자) |
| `encoded` | `{"prd":false,"e2e":false,"test":false}` — **항상 all-false**(Phase 2 증류가 갱신) |

**statement 소독 규칙** (append 전 오케스트레이터가 적용 — § 마찰 로그 detail 규칙과 동일, 길이만 다름):
1. 큰따옴표 `"` → 작은따옴표 `'`
2. 줄바꿈(LF)·캐리지리턴(CR)을 공백으로 치환
3. 백슬래시 `\` 제거
4. 200자 초과면 200자로 절단

**friction 채널과의 경계**:
- 프로세스 마찰(Implementer 재시도·Reviewer NEEDS_FIX·E2E FAIL·롤백)은 `§ 마찰 로그`로.
- 제품 의도/오작동 관찰(제품이 무엇을 해야 하는지)은 `§ 의도 로그`로.
- 한 사건이 둘 다 유발하면 각자 기록한다(직교 — 다른 싱크). 제품 버그는 프로세스 마찰 0으로 통과 가능하다.

**규칙**:
- `.harness-intent.jsonl`이 없으면 append를 건너뛴다 (에러 아님 — 비-하네스 환경 대비)
- 같은 statement는 같은 세션(동일 SESSION_ID)에서 1회만 기록한다
- `encoded`는 Phase 1에서 항상 `{"prd":false,"e2e":false,"test":false}`로 기록한다
- 한 의도 = `>>`로 정확히 한 줄만 append (여러 줄 금지 — 관용 파서가 줄 단위로 읽는다)
- 제품 의도 발화가 없는 세션은 0줄(정상 — graceful)
````

- [ ] **Step 3: 검증**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
F=skills/harness-scaffold/templates/rules/session-routine.md
grep -q '4.2 의도 적재' "$F" && echo "STEP4.2 OK"
grep -q '^## 의도 로그' "$F" && echo "SECTION OK"
grep -q 'harness-intent.jsonl' "$F" && grep -q '200자로 절단' "$F" && grep -q 'all-false' "$F" && echo "RULES OK"
# 신규 플레이스홀더 0 확인 (이번 편집이 새 {{...}}를 도입하지 않았는지 — git diff 추가줄만)
git diff "$F" | grep '^+' | grep -c '{{'
```
Expected:
```
STEP4.2 OK
SECTION OK
RULES OK
0
```
(마지막 `0` = 추가된 줄에 신규 플레이스홀더 없음.)

- [ ] **Step 4: 스키마 정합성 교차검증 (Task 1 ↔ Task 2)**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
for F in skills/harness-scaffold/templates/INTENT_LEDGER.md skills/harness-scaffold/templates/rules/session-routine.md; do
  echo -n "$F: "
  grep -oE '"(ts|session|kind|surface|feature|statement|encoded)"' "$F" | sort -u | tr '\n' ' '; echo
done
```
Expected (두 줄의 필드 집합이 동일):
```
.../INTENT_LEDGER.md: "encoded" "feature" "kind" "session" "statement" "surface" "ts"
.../session-routine.md: "encoded" "feature" "kind" "session" "statement" "surface" "ts"
```

- [ ] **Step 5: 커밋**

```bash
git add skills/harness-scaffold/templates/rules/session-routine.md
git commit -m "$(cat <<'EOF'
feat(templates): session-routine § 의도 로그 + 세션 종료 Step 4.2 적재 (이슈 #15)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: harness-scaffold/SKILL.md — 생성 규칙 배선

**Files:**
- Modify: `skills/harness-scaffold/SKILL.md` (line 36, 221–224, §5.7 line 633, §5.12 끝 ~line 831, §5.13 line 926, §6.2 line 1188–1189, §10.1 line 1518)

**Interfaces:**
- Consumes: Task 1(INTENT_LEDGER.md 템플릿 존재)·Task 2(§ 의도 로그). 새 §5.12.4의 스키마는 Task 1·2와 **동일**.
- Produces: scaffold가 의도 싱크·정적 doc을 생성·manifest 등록·검증하도록 만드는 정규 사양.

- [ ] **Step 1: 생성 순서에 17-d/17-e 추가 (line 221–224)**

현재:
```
17. docs/HARNESS_FRICTION.md (마찰 이벤트 정적 참조 문서 — § 5.12)
17-b. .harness-friction.jsonl (빈 마찰 로그 싱크 — 프로젝트 루트, data 카테고리; harness-feedback이 파일 부재와 0건을 구분하도록 빈 파일로 생성 — § 5.12.1)
17-c. .harness-feedback-cursor (빈 보고 위치 북마크 — 프로젝트 루트, data 카테고리 — § 5.12.2)
18. package.json scripts 추가 (harness:check 포함; e2e 옵트인 시 test:e2e + @playwright/test devDep — § 5.5)
```
`17-c` 다음, `18.` 앞에 두 줄 삽입:
```
17-d. docs/INTENT_LEDGER.md (의도 원장 정적 참조 문서 — § 5.12.3)
17-e. .harness-intent.jsonl (빈 의도 원장 싱크 — 프로젝트 루트, data 카테고리; 부재와 0건 구분 위해 빈 파일 — § 5.12.4)
```

- [ ] **Step 2: 파일 수 갱신 (line 36)**

현재 줄에서 `19개 파일` → `21개 파일`로 바꾼다 (INTENT_LEDGER.md + .harness-intent.jsonl 2개 추가):
```
- 프로필 데이터를 기반으로 21개 파일을 의존 순서대로 생성한다 (+ package.json scripts 수정, 옵트인 시 ESLint 설정 수정·외부 통합 연계 렌더링)
```

- [ ] **Step 3: §5.12.3 + §5.12.4 생성 규칙 추가 (§5.12.2 다음, §5.13 앞 — line 831 뒤)**

`### 5.12.2 .harness-feedback-cursor 생성 규칙` 블록 마지막 줄(line 830) 다음, `### 5.13` 앞에 추가:

````markdown
### 5.12.3 docs/INTENT_LEDGER.md 생성 규칙

- 이 스킬의 `templates/INTENT_LEDGER.md` 템플릿을 그대로 복사하여 생성한다 (플레이스홀더 없음)
- **정적 참조 문서**다 — 제품 의도(intended/unintended) 레코드의 스키마/유형 참조표. 실제 의도는 `.harness-intent.jsonl`(프로젝트 루트, 진실 원본)에 한 줄씩 append되며, session-routine.md `§ 의도 로그`가 기록 주체다 (§ 5.12.4)
- 담는 내용: `kind` 유형(intended/unintended), `surface` 태그 가이드, friction 채널과의 경계, 스키마 참조표, `.harness-intent.jsonl` 포인터, `encoded`에 대한 "Phase 2 증류가 채움" 주석
- HARNESS_FRICTION.md(§ 5.12)와 동일 취급 — doc-freshness 제외 대상(§ 5.7), manifest category `managed`

### 5.12.4 .harness-intent.jsonl 생성 규칙

- 제품 의도의 **진실 원본**이다 — 프로젝트 루트에 둔다(`docs/` 아래가 아님). append-only, git 커밋 대상. 마찰 싱크(`.harness-friction.jsonl`)의 자매
- 스캐폴드 시 **빈 파일**로 생성한다: `: > .harness-intent.jsonl` (또는 `touch .harness-intent.jsonl`). 파일 부재와 0건을 구분하도록 빈 줄도 넣지 않는다
- session-routine.md가 세션 종료 시(§ 세션 종료 Step 4.2) 그 세션의 의도를 증류해 한 줄씩 append한다. 한 줄 = 1 의도, JSON 객체:
  ```json
  {"ts":"2026-06-17T04:30:00Z","session":"2026-06-17T04-12-03Z-a3f9","kind":"intended","surface":"progress","feature":"F007","statement":"진행률 파이차트는 각 날의 태스크만 집계하고 someday는 제외한다","encoded":{"prd":false,"e2e":false,"test":false}}
  ```
  필드: `ts`(적재 시각 ISO8601 UTC), `session`(SESSION_ID — 마찰 로그와 동일 값 공유), `kind`(`intended`|`unintended`), `surface`(영역 kebab 태그), `feature`(feature ID 또는 `""`), `statement`(소독된 의도 한 줄 ≤200자), `encoded`(`{prd,e2e,test}` 승격 상태 — Phase 1 항상 all-false). 기록 시점·소독 규칙은 생성되는 `.claude/rules/session-routine.md § 의도 로그`가 정본
- manifest category는 **`data`**다 (§ 5.13·§ 10.1) — 템플릿 해시 드리프트 검사 제외, 업그레이드 시 덮어쓰지 않음(feature_list.json·.harness-friction.jsonl과 동일)
- **always-on**: 프로필 플래그 없이 무조건 생성한다 (마찰 싱크와 동일). cursor는 Phase 1에 생성하지 않는다 (증류 소비자 미존재)
````

- [ ] **Step 4: §5.13 manifest data 목록 갱신 (line 926)**

현재:
```
| `files.{path}.category` | `managed` / `custom` / `data` (§ 10.1 참조). data 파일(`feature_list.json`·`.harness-friction.jsonl`·`.harness-feedback-cursor`)은 해시 드리프트 검사 제외, 업그레이드 시 덮어쓰지 않음 |
```
data 파일 목록에 `·.harness-intent.jsonl` 추가:
```
| `files.{path}.category` | `managed` / `custom` / `data` (§ 10.1 참조). data 파일(`feature_list.json`·`.harness-friction.jsonl`·`.harness-feedback-cursor`·`.harness-intent.jsonl`)은 해시 드리프트 검사 제외, 업그레이드 시 덮어쓰지 않음 |
```

- [ ] **Step 5: §10.1 파일 분류표에 22-d/22-e 추가 (line 1518 다음)**

`| 22-c | \`.harness-feedback-cursor\` | data | ... |` 줄(line 1518) 다음에 두 행 삽입:
```
| 22-d | `docs/INTENT_LEDGER.md` | managed | 정적 참조 문서(의도 스키마/유형 참조표). 템플릿 기반, 사용자 콘텐츠 없음 |
| 22-e | `.harness-intent.jsonl` | data | 제품 의도 진실 원본(프로젝트 루트). 런타임 데이터 축적, 해시 드리프트 검사 제외 — .harness-friction.jsonl과 동일 취급(always-on) |
```

- [ ] **Step 6: §5.7 doc-freshness 제외 목록 갱신 (line 633)**

현재:
```
  - **이벤트 로그는 제외한다** (docs/HARNESS_FRICTION.md, docs/CLEANUP_LOG.md 등) — 추가형(append-only) 로그는 오래됨이 문제가 아니므로 staleness 경고가 무의미하다
```
`docs/INTENT_LEDGER.md` 추가(HARNESS_FRICTION.md와 동일 취급 — 비대칭 금지):
```
  - **이벤트 로그는 제외한다** (docs/HARNESS_FRICTION.md, docs/INTENT_LEDGER.md, docs/CLEANUP_LOG.md 등) — 추가형(append-only) 로그는 오래됨이 문제가 아니므로 staleness 경고가 무의미하다
```

- [ ] **Step 7: §6.2 검증 ls 갱신 (line 1188–1189)**

현재:
```
# 6.2 docs/ 구조 확인 (HARNESS_FRICTION.md 포함) + 마찰 싱크 확인
ls -la docs/ docs/HARNESS_FRICTION.md .harness-friction.jsonl
```
교체:
```
# 6.2 docs/ 구조 확인 (HARNESS_FRICTION.md·INTENT_LEDGER.md 포함) + 마찰·의도 싱크 확인
ls -la docs/ docs/HARNESS_FRICTION.md docs/INTENT_LEDGER.md .harness-friction.jsonl .harness-intent.jsonl
```

- [ ] **Step 8: 검증**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
F=skills/harness-scaffold/SKILL.md
grep -q '17-d. docs/INTENT_LEDGER.md' "$F" && grep -q '17-e. .harness-intent.jsonl' "$F" && echo "GENORDER OK"
grep -q '21개 파일' "$F" && echo "COUNT OK"
grep -q '### 5.12.3 docs/INTENT_LEDGER.md' "$F" && grep -q '### 5.12.4 .harness-intent.jsonl' "$F" && echo "RULES OK"
grep -q '22-e' "$F" && grep -q '22-d' "$F" && echo "CAT OK"
grep -q 'docs/INTENT_LEDGER.md, docs/CLEANUP_LOG.md' "$F" && echo "FRESHNESS OK"
grep -q 'docs/INTENT_LEDGER.md .harness-friction.jsonl .harness-intent.jsonl' "$F" && echo "VERIFY-LS OK"
# §5.12.4 스키마가 Task 1/2와 동일한지
grep -A6 '### 5.12.4' "$F" | grep -oE '"(ts|session|kind|surface|feature|statement|encoded)"' | sort -u | tr '\n' ' '; echo
```
Expected:
```
GENORDER OK
COUNT OK
RULES OK
CAT OK
FRESHNESS OK
VERIFY-LS OK
"encoded" "feature" "kind" "session" "statement" "surface" "ts"
```

- [ ] **Step 9: 커밋**

```bash
git add skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): harness-scaffold 의도 원장 생성 규칙 — 생성순서·manifest·검증 (이슈 #15)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: §7 능력 카탈로그 — 의도 적재 줄 (수집만)

**Files:**
- Modify: `skills/harness-scaffold/SKILL.md` (§7 카탈로그 line 1393 다음; 렌더링 규칙 line 1425)

**Interfaces:**
- Consumes: Task 2 § 의도 로그(상세 포인터 대상), Task 3 always-on 싱크.
- Produces: 첫 셋업 보고에서 *수집만* 광고하는 능력 줄. **증류·승격은 미배선이므로 광고 금지**(Global Constraints).

- [ ] **Step 1: 능력 줄 추가 (line 1393 마찰 자동 기록 줄 다음)**

현재 (line 1393):
```
- 마찰 자동 기록 → TDD 마찰 이벤트(implementer-retry 등)가 발생 시 `.harness-friction.jsonl`에 자동 기록 (상세: .claude/rules/session-routine.md § 마찰 로그) — always-on
```
바로 다음 줄에 삽입:
```
- 의도 적재 → 세션 종료 시 제품 의도(intended/unintended)가 `.harness-intent.jsonl`에 적재 (상세: .claude/rules/session-routine.md § 의도 로그) — always-on (수집만; 증류·PRD/E2E 승격은 미배선)
```

- [ ] **Step 2: 렌더링 규칙에 의도 적재 추가 (line 1425)**

현재:
```
- **검증 게이트 · 자가진단 · 품질·부채 추적 · 마찰 자동 기록 줄**: 항상 생성되는 산출물이므로 무조건 렌더.
```
교체:
```
- **검증 게이트 · 자가진단 · 품질·부채 추적 · 마찰 자동 기록 · 의도 적재 줄**: 항상 생성되는 산출물이므로 무조건 렌더. (의도 적재 줄은 *수집만* 광고하고 증류·PRD/E2E 승격은 미배선이라 광고하지 않는다 — 미와이어 능력 광고 불가.)
```

- [ ] **Step 3: 검증 (수집만 광고 — 증류를 현재 능력으로 광고하지 않음)**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
F=skills/harness-scaffold/SKILL.md
grep -q '의도 적재 → 세션 종료 시 제품 의도' "$F" && echo "LINE OK"
# 능력 줄이 '수집만'과 '미배선'을 명시하는지 (증류를 현재 능력으로 주장하지 않음)
grep '의도 적재 → 세션 종료' "$F" | grep -q '수집만' && grep '의도 적재 → 세션 종료' "$F" | grep -q '미배선' && echo "CAPTURE-ONLY OK"
grep -q '마찰 자동 기록 · 의도 적재 줄' "$F" && echo "RENDER-RULE OK"
```
Expected:
```
LINE OK
CAPTURE-ONLY OK
RENDER-RULE OK
```

- [ ] **Step 4: 커밋**

```bash
git add skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): Phase 4 능력 카탈로그에 의도 적재 줄 — 수집만 광고 (이슈 #15)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 검증 배선 — harness-check.sh + harness-checklist.md

**Files:**
- Modify: `skills/harness-scaffold/templates/harness-check.sh` (line 22–23 필수 파일 루프)
- Modify: `skills/harness-setup/references/harness-checklist.md` (line 33–34, 37, 219)

**Interfaces:**
- Consumes: Task 3 always-on 싱크(`.harness-intent.jsonl`).
- Produces: 생성 하네스의 자가진단·체크리스트가 의도 싱크 존재를 friction과 동일하게 검사.

- [ ] **Step 1: harness-check.sh 필수 파일 루프에 싱크 추가 (line 22–23)**

현재:
```sh
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt \
         feature_list.json .harness-friction.jsonl init.sh scripts/structural-test.ts scripts/doc-freshness.ts; do
```
`.harness-friction.jsonl` 다음에 `.harness-intent.jsonl` 추가:
```sh
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt \
         feature_list.json .harness-friction.jsonl .harness-intent.jsonl init.sh scripts/structural-test.ts scripts/doc-freshness.ts; do
```

- [ ] **Step 2: harness-checklist.md 체크리스트 항목 추가 (line 33 다음)**

현재 (line 33):
```
- [ ] `.harness-friction.jsonl` — 마찰 자동 기록 싱크 (append-only JSONL, manifest category `data`)
```
다음 줄에 추가:
```
- [ ] `.harness-intent.jsonl` — 제품 의도 적재 싱크 (append-only JSONL, manifest category `data`, always-on)
```

- [ ] **Step 3: harness-checklist.md 검증 ls 두 곳 갱신 (line 37, 219)**

line 37·line 219의 `ls ... .harness-friction.jsonl init.sh ...`에서 `.harness-friction.jsonl` 다음에 `.harness-intent.jsonl`를 추가한다. 두 줄 모두:
```
ls AGENTS.md ARCHITECTURE.md claude-progress.txt feature_list.json .harness-friction.jsonl .harness-intent.jsonl init.sh docs/
```

- [ ] **Step 4: 검증**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
grep -q '.harness-friction.jsonl .harness-intent.jsonl init.sh' skills/harness-scaffold/templates/harness-check.sh && echo "CHECK.SH OK"
grep -q '.harness-intent.jsonl. — 제품 의도 적재 싱크' skills/harness-setup/references/harness-checklist.md && echo "CHECKLIST OK"
grep -c '.harness-friction.jsonl .harness-intent.jsonl init.sh docs/' skills/harness-setup/references/harness-checklist.md
```
Expected:
```
CHECK.SH OK
CHECKLIST OK
2
```
(마지막 `2` = 검증 ls 두 곳 모두 갱신.)

- [ ] **Step 5: 커밋**

```bash
git add skills/harness-scaffold/templates/harness-check.sh skills/harness-setup/references/harness-checklist.md
git commit -m "$(cat <<'EOF'
feat(skill,refs): 의도 싱크 자가진단·체크리스트 배선 (이슈 #15)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 정합성·회귀 검증 게이트 (커밋 없음)

**Files:** (없음 — 검증 전용. 실패 시 해당 Task로 돌아가 수정)

**Interfaces:**
- Consumes: Task 1–5 전체.
- Produces: 릴리스 전 게이트 — 골든 픽스처 회귀 무영향 + 3-파일 스키마 정합 + 신규 플레이스홀더 0 + 프로필 계약 불변.

- [ ] **Step 1: 골든 픽스처 회귀 (structural-test 템플릿 미변경 확인)**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
bash test/run-fixtures.sh; echo "EXIT=$?"
```
Expected: 모든 픽스처 통과, `EXIT=0`. (이 작업은 structural-test 템플릿을 건드리지 않으므로 그린 유지가 정상.)

- [ ] **Step 2: 3-파일 스키마 정합성 (불변 계약)**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
echo "--- 세 곳의 필드 집합이 동일해야 함 ---"
grep -oE '"(ts|session|kind|surface|feature|statement|encoded)"' skills/harness-scaffold/templates/INTENT_LEDGER.md | sort -u | tr '\n' ' '; echo " [INTENT_LEDGER.md]"
grep -oE '"(ts|session|kind|surface|feature|statement|encoded)"' skills/harness-scaffold/templates/rules/session-routine.md | sort -u | tr '\n' ' '; echo " [session-routine § 의도 로그]"
grep -A6 '### 5.12.4' skills/harness-scaffold/SKILL.md | grep -oE '"(ts|session|kind|surface|feature|statement|encoded)"' | sort -u | tr '\n' ' '; echo " [scaffold §5.12.4]"
```
Expected: 세 줄 모두 `"encoded" "feature" "kind" "session" "statement" "surface" "ts"`. 불일치 시 해당 Task 수정.

- [ ] **Step 3: 신규 플레이스홀더 0 + 프로필 계약 불변**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
echo "--- 이번 브랜치가 도입한 신규 {{...}} (0이어야 함) ---"
git diff main...HEAD -- skills/ | grep '^+' | grep -oE '{{[A-Z_]+}}' | sort -u
echo "--- 프로필 입력 스키마(§4)·프로필 스냅샷 변경 0이어야 함 ---"
git diff main...HEAD -- skills/harness-scaffold/SKILL.md | grep -E '^\+' | grep -iE 'profile\.|프로필 입력 스키마|## 4\.' | grep -iv 'INTENT_LEDGER\|의도\|intent' || echo "(프로필 스키마 변경 없음 — OK)"
```
Expected: 첫 블록 출력 없음(신규 플레이스홀더 0), 둘째 블록 `(프로필 스키마 변경 없음 — OK)`.

- [ ] **Step 4: 생성 파일 목록 ↔ templates/ 정합 (CLAUDE.md 정합성 검사 #3)**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
test -f skills/harness-scaffold/templates/INTENT_LEDGER.md && grep -q '17-d. docs/INTENT_LEDGER.md' skills/harness-scaffold/SKILL.md && echo "GEN↔TEMPLATE OK"
```
Expected: `GEN↔TEMPLATE OK`. (4개 검증 모두 통과해야 Task 7로 진행. 이 태스크는 커밋하지 않는다.)

---

### Task 7: 버전 범프 1.24.0 + 트래킹

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`, `skills/harness-setup/references/project-context.md`
- Modify: `.tracking/CHANGELOG.md`, `.tracking/HANDOFF.md`, `.tracking/TODO.md`

**Interfaces:**
- Consumes: Task 1–6 완료(검증 통과).
- Produces: 1.24.0 릴리스 메타 + 세션 트래킹.

- [ ] **Step 1: 1.23.0 → 1.24.0 전수 갱신**

먼저 모든 발생 위치를 찾는다:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
grep -rn '1\.23\.0' --include='*.json' --include='*.md' --include='*.sh' . | grep -v node_modules | grep -v '/CHANGELOG.md:' | grep -v 'docs/superpowers/'
```
출력된 각 위치(plugin.json `"version"`, marketplace.json plugin 버전, README.md 버전 줄, project-context.md 버전 헤더, 그리고 SKILL.md/매니페스트의 harness 버전 상수가 있으면)를 `1.24.0`으로 바꾼다. **단, 과거 이력(CHANGELOG 기존 항목·이미 작성된 spec)은 건드리지 않는다** (위 grep이 그 둘을 제외함).

검증:
```bash
grep -rn '1\.23\.0' --include='*.json' --include='*.md' --include='*.sh' . | grep -v node_modules | grep -v '/CHANGELOG.md:' | grep -v 'docs/superpowers/' || echo "(1.23.0 잔존 없음 — OK)"
grep -m1 '"version"' .claude-plugin/plugin.json
```
Expected: `(1.23.0 잔존 없음 — OK)`, plugin.json version `1.24.0`.

- [ ] **Step 2: CHANGELOG.md 항목 추가**

`.tracking/CHANGELOG.md` 최상단(또는 버전 정책에 맞는 위치)에 추가:
```markdown
## [1.24.0] — 2026-06-17

### Added
- **Intent Ledger — Phase 1 수집 인프라 (이슈 #15)**: friction 자매 채널. 세션 종료 시 제품 의도(intended/unintended)를 `.harness-intent.jsonl`(append-only, git 추적, manifest `data`, always-on)에 증류 적재.
  - `templates/INTENT_LEDGER.md` 정적 참조 문서(스키마·kind·surface·friction 경계).
  - session-routine `§ 의도 로그` + 세션 종료 Step 4.2 적재 규칙.
  - scaffold 생성순서 17-d/17-e, §5.12.3/5.12.4, manifest §5.13·§10.1, doc-freshness 제외, §6.2 검증.
  - Phase 4 능력 카탈로그 의도 적재 줄(수집만 — 증류·승격은 미배선).
  - harness-check.sh·harness-checklist.md 싱크 검증.
- 스키마: `{ts, session, kind, surface, feature, statement(≤200), encoded:{prd,e2e,test}}`. `encoded`는 Phase 1 항상 all-false. SESSION_ID는 friction과 공유.
- 프로필 변경 0, 신규 플레이스홀더 0. 증류·추적·PRD 바인딩은 Phase 2(비-스코프).
```

- [ ] **Step 3: project-context.md 설계 결정 + 버전 히스토리**

`skills/harness-setup/references/project-context.md`에:
- 버전 히스토리에 `1.24.0 — Intent Ledger Phase 1 수집 인프라(이슈 #15)` 추가.
- § 설계 결정 사항에 한 줄: "의도 원장은 friction 자매 채널 — 세션 종료 배치 적재, always-on, encoded 선반영(Phase 1 all-false), unintended↔friction 직교. 증류는 Phase 2."

- [ ] **Step 4: HANDOFF.md + TODO.md**

- `.tracking/HANDOFF.md`: 현재 상태에 "Intent Ledger Phase 1 완료(이슈 #15) — 수집 인프라 배선. Phase 2(증류) 미착수." 반영. P-커버리지 테이블이 있으면 갱신.
- `.tracking/TODO.md`: Phase 2 항목 추가 — "intent-distill 스킬 / PRD diff / E2E 백로그 / encoded 갱신 / intent↔PRD 바인딩 + PRD 출력단 갭(빈 docs/product-specs, feature_list.id→PRD 링크 필드) — spec §12 참조."

- [ ] **Step 5: 검증 + 커밋**

Run:
```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
grep -q '1.24.0' .tracking/CHANGELOG.md && grep -q '1.24.0' skills/harness-setup/references/project-context.md && echo "TRACKING OK"
```
Expected: `TRACKING OK`.

```bash
git add .tracking/CHANGELOG.md .tracking/HANDOFF.md .tracking/TODO.md \
        skills/harness-setup/references/project-context.md \
        .claude-plugin/plugin.json .claude-plugin/marketplace.json README.md
git commit -m "$(cat <<'EOF'
chore(skill,tracking): 1.24.0 버전 범프 + 의도 원장 트래킹 (이슈 #15)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

> **git tag**: `v1.24.0` 태그는 feature 브랜치가 아니라 **main 병합 시점**에 생성한다 (CLAUDE.md 버전 정책의 `git tag`는 릴리스 단계). 이 플랜에서는 태그하지 않는다.

---

## 실전 스모크 (선택 — 병합 전 권장)

실제 프로젝트에서 scaffold를 돌려 싱크/문서 생성을 눈으로 확인한다(자동 테스트 없음 — CLAUDE.md "실전 테스트"):
```
# 대상 프로젝트에서: /harness-scaffold (또는 업그레이드)
# 확인: docs/INTENT_LEDGER.md 생성, .harness-intent.jsonl 빈 파일 생성,
#       .harness-manifest.json에 두 항목 등록(category data/managed),
#       npm run harness:check → .harness-intent.jsonl ✅
```

---

## Self-Review (작성자 체크 결과)

**1. Spec coverage** (spec §4 구성요소 → 태스크 매핑):
- §4.1 싱크 → Task 3(§5.12.4 생성규칙) + Task 1(스키마 doc). ✓
- §4.2 session-routine(Step 4.2 + § 의도 로그) → Task 2. ✓
- §4.3 INTENT_LEDGER.md → Task 1 + Task 3(§5.12.3 생성규칙). ✓
- §4.4 scaffold(생성순서·manifest·§6·§7 게이팅) → Task 3 + Task 4. ✓
- §4.5 검증 배선(harness-check/checklist) → Task 5. ✓
- §9 버전/마이그레이션 → Task 7. ✓
- §10 검증계획 → Task 1–6 verify 스텝 + Task 6 게이트. ✓
- §11 수용기준 8개 → 각 Task verify로 커버(스키마 정합 Task6 S2, 능력 수집만 Task4 S3, 프로필 불변 Task6 S3). ✓

**2. Placeholder scan**: "TBD/TODO/적절히 처리" 없음. 모든 편집은 전체 내용 제시. ✓

**3. Type/스키마 일관성**: 7-필드 스키마가 Task 1·2·3에서 동일 문자열, Task 6 S2가 교차검증. `kind` enum(intended/unintended)·소독 규칙(≤200)·encoded all-false가 세 곳 일치. ✓
