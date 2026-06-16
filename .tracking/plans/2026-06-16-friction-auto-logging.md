# 마찰 자동 기록 (저비용 JSONL 싱크) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 생성 하네스의 마찰 이벤트를 산문 의존이 아닌 저비용 단일 JSON 라인 append(`.harness-friction.jsonl`)로 자동 기록해, harness-feedback의 피드백 루프 dead-letter(이슈 #9)를 마감한다.

**Architecture:** 진실 원본은 프로젝트 루트 `.harness-friction.jsonl`(append-only). 오케스트레이터(session-routine.md)가 마찰 발생 즉시 소독된 JSON 1줄을 append하는 것이 주 메커니즘이다. `HARNESS_FRICTION.md`는 정적 참조 문서로 격하하고, harness-feedback이 jsonl을 직접·관용 파싱한다. Stop hook / settings.json / 렌더러는 두지 않는다(옵션 i — 멀티모델 자문 종합).

**Tech Stack:** harness-setup 스킬 소스(마크다운 SKILL.md 사양 + 템플릿). 검증은 `bash test/run-fixtures.sh`(골든 픽스처) + grep 정합성 + `_sandbox` 스캐폴드 스모크 테스트. 스택 비종속(append=bash echo, 읽기=cat+LLM 파싱, 외부 도구 0).

**정본 스키마 (모든 태스크가 정확히 일치해야 함 — 스펙 §4):**
`.harness-friction.jsonl` 한 줄 = 1 JSON 객체, 필드 순서/이름:
```json
{"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-a3f9","event":"implementer-retry","severity":"high","feature":"F-12","detail":"타입 에러 3회 반복"}
```
- `ts` ISO8601 UTC · `session` SESSION_ID(`{ISO 시각}-{4자 난수}`) · `event` enum · `severity` `low|medium|high|critical` · `feature` ID 또는 `""` · `detail` 소독된 ≤50자
- SESSION_ID는 세션 시작 시 1회 생성, `claude-progress.txt`에 `SESSION_ID: <값>`으로 기록
- detail 소독: `"`→`'` / 줄바꿈·CR→공백 / `\` 제거 / ≤50자
- event enum(TDD): `implementer-retry`(high)·`debugger-escalation`(critical)·`user-escalation`(critical)·`review-fix`(medium)·`refactor-rollback`(high)·`e2e-fail`(high)·`session-incomplete`(low)
- manifest category: `.harness-friction.jsonl`=`data`(드리프트 검사 제외), `docs/HARNESS_FRICTION.md`=`managed`(정적 문서로 격하)

**설계 정본:** `.tracking/specs/2026-06-16-friction-auto-logging-design.md`

> **자체 검토 반영(4건)**: ① HARNESS_FRICTION.md manifest category를 양쪽 SKILL.md에서 `managed`로 통일(정적 문서화). ② "이제 할 수 있는 일" 카탈로그(harness-scaffold §7)에 마찰 자동 기록 줄 추가(GAP A). ③ versioning-policy.md §7 예시표에 1.18.0 행 추가(GAP B). ④ 프로필 version 범프는 Task 7(릴리스)에서 일괄 처리(중복 방지).

---

### Task 1: session-routine.md — 마찰 기록을 JSONL append로 교체 + SESSION_ID

**Files:**
- Modify: `templates/rules/session-routine.md`

- [ ] **Step 1: 세션 시작에 SESSION_ID 발급 단계 추가** (`### Step 1: 상태 복원` 코드블록 직후)

Old:
```
### Step 1: 상태 복원
```
1. claude-progress.txt를 읽는다
2. "=== TDD STATE ===" 블록이 있으면 중단된 사이클을 이어받는다
3. git status로 미커밋 변경 확인 (있으면 사용자에게 알림)
4. git log --oneline -10으로 최근 커밋을 확인한다
5. TDD STATE 블록과 git 이력의 정합성 확인
```
```
New: 위 블록 **뒤에** 다음을 삽입(기존 블록은 그대로 유지):
```
### Step 1.5: 세션 ID 발급

세션마다 1회 고유 ID를 발급하고 claude-progress.txt에 기록한다. 이 세션의 모든 마찰 줄(§ 마찰 로그)이 동일 값을 참조하므로, `harness-feedback`이 같은 날 복수 세션을 구분해 그룹핑·패턴 분석할 수 있다.

​```
1. claude-progress.txt에 이미 "SESSION_ID: "로 시작하는 줄이 있으면(재개 세션) 그 값을 그대로 사용한다
2. 없으면 ID를 1회 생성한다 — 형식: {ISO 시각}-{4자 난수}
   - 시각은 UTC, 콜론은 하이픈으로 치환 (파일명·줄 안전): 2026-06-16T09-12-03Z
   - 난수는 소문자 영숫자 4자: a3f9
   - 예: 2026-06-16T09-12-03Z-a3f9
3. claude-progress.txt에 "SESSION_ID: <값>" 한 줄을 기록한다
​```
```
(주: 위 `​```` 펜스는 실제 백틱 3개로 작성한다 — 이 문서에서 중첩 표시용으로만 zero-width 삽입됨.)

- [ ] **Step 2: 검증 루프/분기 7곳의 "마찰 로그 기록 (X)"를 JSONL append 표현으로 교체**

각 old→new (verbatim):
| # | Old | New |
|---|-----|-----|
| L129 | `    if attempt >= 2 → 마찰 로그 기록 (implementer-retry)` | `    if attempt >= 2 → 마찰 이벤트 기록(implementer-retry) — § 마찰 로그 참조(.harness-friction.jsonl에 append)` |
| L133 | `if 실패:`⏎`    마찰 로그 기록 (debugger-escalation)`⏎`    Debugger 에스컬레이션` | `if 실패:`⏎`    마찰 이벤트 기록(debugger-escalation) — § 마찰 로그 참조(.harness-friction.jsonl에 append)`⏎`    Debugger 에스컬레이션` |
| L147 | `if 실패:`⏎`    마찰 로그 기록 (user-escalation)`⏎`    사용자에게 진단 보고서 제시` | `if 실패:`⏎`    마찰 이벤트 기록(user-escalation) — § 마찰 로그 참조(.harness-friction.jsonl에 append)`⏎`    사용자에게 진단 보고서 제시` |
| L162 | `- NEEDS_FIX → 마찰 로그 기록 (review-fix) → Phase 3 (Green) 재진입 (시도 횟수 누적)` | `- NEEDS_FIX → 마찰 이벤트 기록(review-fix) — § 마찰 로그 참조(.harness-friction.jsonl에 append) → Phase 3 (Green) 재진입 (시도 횟수 누적)` |
| L202 | `- FAIL(로직) → 마찰 로그 기록(`+"`e2e-fail`"+`) → Phase 3 (Green) 재진입, **시도 횟수 누적**(`+"`{{MAX_IMPLEMENTER_ATTEMPTS}}`"+` 한도 — NEEDS_FIX와 동일).` | `- FAIL(로직) → 마찰 이벤트 기록(`+"`e2e-fail`"+`) — § 마찰 로그 참조(.harness-friction.jsonl에 append) → Phase 3 (Green) 재진입, **시도 횟수 누적**(`+"`{{MAX_IMPLEMENTER_ATTEMPTS}}`"+` 한도 — NEEDS_FIX와 동일).` |
| L217 | `- FAIL (2회) → 마찰 로그 기록 (refactor-rollback) → 리팩터링 전부 되돌리고, un-refactored 코드로 Complete` | `- FAIL (2회) → 마찰 이벤트 기록(refactor-rollback) — § 마찰 로그 참조(.harness-friction.jsonl에 append) → 리팩터링 전부 되돌리고, un-refactored 코드로 Complete` |

- [ ] **Step 3: 세션 종료 절차에 session-incomplete append (안전망) 명시** (`## 세션 종료` 의사코드)

Old:
```
4. 진행 중인 TDD 사이클이 있으면:
   - TDD STATE 블록 저장
   - 마찰 로그 기록 (session-incomplete)
```
New:
```
4. 진행 중인 TDD 사이클이 있으면:
   - TDD STATE 블록 저장
   - 마찰 이벤트 기록(session-incomplete) — § 마찰 로그 참조(.harness-friction.jsonl에 append)
     (사이클 미완료로 종료될 때의 안전망 기록 — 종료 시점에 반드시 1줄 append)
```

- [ ] **Step 4: `## 마찰 로그` 섹션 전체 교체** (스펙 §5.2·§6.1·§4.1)

Old: 현재 `## 마찰 로그` 섹션 전체(L284-307, "TDD 사이클 중 마찰 이벤트가 발생하면 `docs/HARNESS_FRICTION.md`의 로그 테이블에 행을 추가한다." ~ "상세 필드는 ... (50자 이내)"까지).
New (전체 교체):
```
## 마찰 로그

TDD 사이클 중 마찰 이벤트가 발생하면 `.harness-friction.jsonl`(프로젝트 루트, append-only)에 **소독된 JSON 한 줄을 append**한다. 무거운 마크다운 테이블 편집(읽기→탐색→삽입→재작성) 대신 단일 append이므로 부하 상황에서도 건너뛰지 않는다. 이렇게 쌓인 줄을 `harness-feedback`이 읽어 패턴을 분석한다.

**기록 방법** — 한 줄을 그대로 append한다(`>>`):
​```
echo '{"ts":"2026-06-16T12:34:56Z","session":"<SESSION_ID>","event":"implementer-retry","severity":"high","feature":"F-12","detail":"<소독된 한 줄>"}' >> .harness-friction.jsonl
​```

**필드** (한 줄 = 1 이벤트):
| 필드 | 값 |
|------|------|
| `ts` | 이벤트 발생 시각, ISO8601 UTC (예: `2026-06-16T12:34:56Z`) |
| `session` | § 세션 시작 Step 1.5에서 발급한 SESSION_ID (claude-progress.txt의 `SESSION_ID:` 값) |
| `event` | 아래 이벤트 유형 enum |
| `severity` | `low` \| `medium` \| `high` \| `critical` (이벤트 유형 표의 심각도) |
| `feature` | 현재 feature ID, 없으면 `""` |
| `detail` | 소독된 원인 한 줄 (아래 detail 소독 규칙) |

**detail 소독 규칙** (append 전 오케스트레이터가 적용 — JSON이 깨지지 않게):
1. 큰따옴표 `"` → 작은따옴표 `'`
2. 줄바꿈(LF)·캐리지리턴(CR)을 공백으로 치환(제거)
3. 백슬래시 `\` 제거
4. 50자 초과면 50자로 절단

**이벤트 유형**:
| 이벤트 | 기록 시점 | 심각도 |
|--------|----------|--------|
| `implementer-retry` | Implementer 2회째 실패 시 | high |
| `debugger-escalation` | Implementer 한도 초과 → Debugger 호출 시 | critical |
| `user-escalation` | Debugger도 한도 초과 → 사용자 보고 시 | critical |
| `review-fix` | Reviewer가 NEEDS_FIX 반환 시 | medium |
| `refactor-rollback` | Simplifier 2회 실패 → 롤백 시 | high |
| `e2e-fail` | VERIFY(E2E)가 FAIL 반환 시 | high |
| `session-incomplete` | TDD 사이클 미완료 상태로 세션 종료 시 | low |

**규칙**:
- `.harness-friction.jsonl`이 없으면 append를 건너뛴다 (에러 아님 — 스캐폴드 시 빈 파일로 생성되지만, 비-하네스 환경 대비)
- 같은 feature의 같은 이벤트가 같은 세션(동일 SESSION_ID)에서 반복되면 첫 번째만 기록한다
- `detail`은 에러 메시지의 핵심 한 줄 또는 원인 요약을 위 소독 규칙으로 가공한 결과 (≤50자)
- 한 이벤트 = `>>`로 정확히 한 줄만 append (여러 줄 금지 — 관용 파서가 줄 단위로 읽는다)
```

- [ ] **Step 5: 검증**

Run: `grep -nE 'harness-friction.jsonl|마찰 이벤트 기록|SESSION_ID' templates/rules/session-routine.md && ! grep -nE '로그 테이블에 행을 추가|마찰 로그 기록 ' templates/rules/session-routine.md && echo OK`
Expected: 첫 grep 다수 매치(§마찰 로그 본문·7개 분기·Step 1.5), 두 번째 부정 grep 0건, 마지막 `OK` 출력.

- [ ] **Step 6: Commit**

```bash
git add templates/rules/session-routine.md
git commit -m "feat(templates): 마찰 기록을 JSONL append로 교체 + SESSION_ID (이슈 #9, TODO-84)"
```

---

### Task 2: harness-scaffold/SKILL.md — 싱크 생성 + manifest data 등록 + 카탈로그 + 격하

**Files:**
- Modify: `harness-scaffold/SKILL.md`

- [ ] **Step 1: 생성 순서에 빈 `.harness-friction.jsonl` 추가** (§5 생성 순서, 17번 직후)

Old:
```
17. docs/HARNESS_FRICTION.md (마찰 로그 — 피드백 수집)
18. package.json scripts 추가 (harness:check 포함; e2e 옵트인 시 test:e2e + @playwright/test devDep — § 5.5)
```
New:
```
17. docs/HARNESS_FRICTION.md (마찰 이벤트 정적 참조 문서 — § 5.12)
17-b. .harness-friction.jsonl (빈 마찰 로그 싱크 — 프로젝트 루트, data 카테고리; harness-feedback이 파일 부재와 0건을 구분하도록 빈 파일로 생성 — § 5.12.1)
18. package.json scripts 추가 (harness:check 포함; e2e 옵트인 시 test:e2e + @playwright/test devDep — § 5.5)
```

- [ ] **Step 2: §5.12 격하 + §5.12.1 싱크 생성 규칙 신설**

Old:
```
### 5.12 docs/HARNESS_FRICTION.md 생성 규칙

- 이 스킬의 `templates/HARNESS_FRICTION.md` 템플릿을 그대로 복사하여 생성한다 (플레이스홀더 없음)
- TDD 세션 중 발생하는 마찰 이벤트를 자동으로 기록하는 로그 파일이다
- session-routine.md가 마찰 이벤트 감지 시 이 파일에 행을 추가한다
- 기록 형식: `| {날짜} | {이벤트} | {심각도} | {feature} | {상세} |`
- 이벤트 유형: `implementer-retry`, `debugger-escalation`, `user-escalation`, `review-fix`, `refactor-rollback`, `session-incomplete`
```
New:
```
### 5.12 docs/HARNESS_FRICTION.md 생성 규칙

- 이 스킬의 `templates/HARNESS_FRICTION.md` 템플릿을 그대로 복사하여 생성한다 (플레이스홀더 없음)
- **정적 참조 문서**다 — 더 이상 마찰 로그 테이블을 담지 않는다. 마찰 이벤트는 `.harness-friction.jsonl`(프로젝트 루트, 진실 원본)에 한 줄씩 append되며, session-routine.md가 기록 주체다 (§ 5.12.1)
- 담는 내용: 이벤트 유형/심각도 참조표, 하네스 이슈 보고 안내, 그리고 "마찰 이벤트는 `.harness-friction.jsonl`에 자동 기록되며 '하네스 피드백 분석해줘'로 분석한다"는 포인터
- 이벤트 유형 (참조용): TDD — `implementer-retry`(high), `debugger-escalation`(critical), `user-escalation`(critical), `review-fix`(medium), `refactor-rollback`(high), `e2e-fail`(high), `session-incomplete`(low); 하네스 이슈 — `setup-mismatch`, `structural-test-false-positive/negative`, `init-failure`, `rule-conflict`, `agent-hallucination`, `doc-stale`(harness-cleanup가 기록)

### 5.12.1 .harness-friction.jsonl 생성 규칙

- 마찰 이벤트의 **진실 원본**이다 — 프로젝트 루트에 둔다(`docs/` 아래가 아님). append-only, git 커밋 대상
- 스캐폴드 시 **빈 파일**로 생성한다: `: > .harness-friction.jsonl` (또는 `touch .harness-friction.jsonl`). harness-feedback이 파일 부재("not found")와 0건("기록된 이벤트 없음")을 구분할 수 있도록 빈 줄도 넣지 않는다
- session-routine.md가 마찰 이벤트 감지 시 한 줄을 append한다. 한 줄 = 1 이벤트, JSON 객체:
  ​```json
  {"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-a3f9","event":"implementer-retry","severity":"high","feature":"F-12","detail":"타입 에러 3회 반복"}
  ​```
  필드: `ts`(이벤트 발생 시각 ISO8601 UTC), `session`(세션 고유 ID — `{ISO 시각}-{4자 난수}` 예 `2026-06-16T09-12-03Z-a3f9`), `event`(이벤트 유형 enum), `severity`(`low`|`medium`|`high`|`critical`), `feature`(feature ID 또는 `""`), `detail`(소독된 원인 한 줄 ≤50자). 기록 시점·소독 규칙·세션 ID 생성은 생성되는 `.claude/rules/session-routine.md`가 정본
- manifest category는 **`data`**다 (§ 5.13·§ 10.1) — 템플릿 해시 드리프트 검사 제외(feature_list.json과 동일 취급). harness-feedback이 직접 읽고 분석하는 입력이다
- **이 증분에서 Stop hook / `.claude/settings.json` / friction-detect.mjs는 생성하지 않는다** (옵션 i — 오케스트레이터의 저비용 append가 주 메커니즘)
```

- [ ] **Step 3: §10.1 파일별 분류 테이블 — HARNESS_FRICTION.md를 managed로 재분류 + jsonl data 추가**

Old:
```
| 22 | `docs/HARNESS_FRICTION.md` | data | session-routine이 마찰 이벤트 기록 |
```
New:
```
| 22 | `docs/HARNESS_FRICTION.md` | managed | 정적 참조 문서(이벤트 유형/심각도 참조표). 템플릿 기반, 사용자 콘텐츠 없음 |
| 22-b | `.harness-friction.jsonl` | data | 마찰 이벤트 진실 원본(프로젝트 루트). 런타임 데이터 축적, 해시 드리프트 검사 제외 — feature_list.json과 동일 취급 |
```

- [ ] **Step 4: §6.2 검증 + §7 보고 파일 테이블에 싱크 반영**

Edit A — §6.2:
Old: `# 6.2 docs/ 구조 확인 (HARNESS_FRICTION.md 포함)`⏎`ls -la docs/ docs/HARNESS_FRICTION.md`
New: `# 6.2 docs/ 구조 확인 (HARNESS_FRICTION.md 포함) + 마찰 싱크 확인`⏎`ls -la docs/ docs/HARNESS_FRICTION.md .harness-friction.jsonl`

Edit B — §7 보고 생성 파일 테이블:
Old: `| docs/HARNESS_FRICTION.md | ✅ | 마찰 로그 (피드백 수집) |`
New:
```
| docs/HARNESS_FRICTION.md | ✅ | 마찰 이벤트 정적 참조 문서 |
| .harness-friction.jsonl | ✅ | 마찰 로그 싱크 (빈 파일 — 자동 기록 대상) |
```

- [ ] **Step 5: §7 "이제 할 수 있는 일" 카탈로그에 마찰 자동 기록 줄 추가 (GAP A)**

Edit A — 카탈로그 목록 (`피드백 분석 → ...` 줄 직후 삽입):
Old: `- 피드백 분석 → "하네스 피드백 분석해줘" (상세: CLAUDE.md 하네스 이슈 보고 — 컴패니언, 글로벌 설치 전제)`
New: 위 줄 **뒤에** 다음 줄 삽입(기존 줄 유지):
```
- 마찰 자동 기록 → TDD 마찰 이벤트(implementer-retry 등)가 발생 시 `.harness-friction.jsonl`에 자동 기록 (상세: .claude/rules/session-routine.md § 마찰 로그) — always-on
```

Edit B — 렌더링 규칙 (always-render 줄에 마찰 자동 기록 포함):
Old: `- **검증 게이트 · 자가진단 · 품질·부채 추적 줄**: 항상 생성되는 산출물이므로 무조건 렌더.`
New: `- **검증 게이트 · 자가진단 · 품질·부채 추적 · 마찰 자동 기록 줄**: 항상 생성되는 산출물이므로 무조건 렌더.`

- [ ] **Step 6: 검증**

Run: `grep -nE 'harness-friction.jsonl|17-b|22-b|5.12.1|마찰 자동 기록' harness-scaffold/SKILL.md && ! grep -nE 'friction-detect|settings\.json' harness-scaffold/SKILL.md && echo OK`
Expected: 17-b·22-b·§5.12.1·카탈로그 줄·jsonl 다수 매치, friction-detect/settings.json 0건, `OK`.

- [ ] **Step 7: Commit**

```bash
git add harness-scaffold/SKILL.md
git commit -m "feat(skill): scaffold가 .harness-friction.jsonl 생성 + manifest data 등록 + 카탈로그 (이슈 #9)"
```

---

### Task 3: templates/HARNESS_FRICTION.md — 정적 참조 문서로 격하

**Files:**
- Modify: `templates/HARNESS_FRICTION.md`

- [ ] **Step 1: 헤더 인용문 교체**

Old:
```
> 이 파일은 TDD 세션 중 발생한 마찰 이벤트를 자동으로 기록한다.
> 하네스 개선 피드백으로 활용된다. 수동 메모도 자유롭게 추가 가능.
```
New:
```
> 이 파일은 마찰 이벤트의 **유형/심각도 참조표**다 (정적 문서).
> 실제 이벤트는 프로젝트 루트의 `.harness-friction.jsonl`에 한 줄씩 자동 기록되며,
> "하네스 피드백 분석해줘"로 누적된 로그를 분석해 하네스 개선 피드백으로 활용한다.
```

- [ ] **Step 2: `## 로그` 테이블 → `## 자동 기록 & 분석` 교체** (이벤트 유형 참조표·이슈 보고 섹션은 보존)

Old:
```
## 로그

| 날짜 | 이벤트 | 심각도 | feature | 상세 |
|------|--------|--------|---------|------|

## 이슈 보고
```
New:
```
## 자동 기록 & 분석

마찰 이벤트는 이 파일이 아니라 프로젝트 루트의 `.harness-friction.jsonl`에 한 줄씩 자동 기록된다 (append-only, git 커밋). 한 줄 = 1 이벤트, JSON Lines 형식:

​```json
{"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-a3f9","event":"implementer-retry","severity":"high","feature":"F-12","detail":"타입 에러 3회 반복"}
​```

| 필드 | 의미 |
|------|------|
| `ts` | 이벤트 발생 시각 (ISO8601 UTC) |
| `session` | 세션 고유 ID (`{ISO 시각}-{4자 난수}`, 예 `2026-06-16T09-12-03Z-a3f9`) |
| `event` | 위 참조표의 이벤트 유형 enum |
| `severity` | `low` \| `medium` \| `high` \| `critical` |
| `feature` | feature ID 또는 `""` |
| `detail` | 소독된 원인 한 줄 (≤50자) |

오케스트레이터(`session-routine.md` 참조)가 마찰 발생 시점에 단일 JSON 라인을 append한다. 누적된 로그는 **"하네스 피드백 분석해줘"**로 분석하면 `harness-feedback`이 `.harness-friction.jsonl`을 파싱해 반복 패턴을 식별하고 개선 Issue를 제안한다.

## 이슈 보고
```

- [ ] **Step 3: 검증**

Run: `grep -c 'harness-friction.jsonl' templates/HARNESS_FRICTION.md && ! grep -q '^| 날짜 | 이벤트' templates/HARNESS_FRICTION.md && echo OK`
Expected: jsonl ≥3회, `| 날짜 | 이벤트` 헤더 없음, `OK`. 이벤트 유형 참조표(L6-29)·이슈 보고 섹션 보존 확인.

- [ ] **Step 4: Commit**

```bash
git add templates/HARNESS_FRICTION.md
git commit -m "feat(templates): HARNESS_FRICTION.md 정적 참조 문서로 격하 (이슈 #9)"
```

---

### Task 4: SKILL.md — 분석 스킬 계약 동기화 (version 제외)

**Files:**
- Modify: `SKILL.md`

> version 범프(L550)는 **Task 7(릴리스)에서 일괄 처리** — 이 태스크에서는 건드리지 않는다(중복 방지).

- [ ] **Step 1: Step 5 생성 예정 파일 목록에 `.harness-friction.jsonl` 추가**

Old:
```
13. docs/HARNESS_FRICTION.md
14. docs/ 하위 디렉토리
15. scripts/structural-test.ts
16. scripts/doc-freshness.ts
17. scripts/harness-check.sh (하네스 자가진단)
```
New:
```
13. docs/HARNESS_FRICTION.md (마찰 유형 참조 문서)
14. .harness-friction.jsonl (마찰 이벤트 자동 기록 싱크 — 빈 파일)
15. docs/ 하위 디렉토리
16. scripts/structural-test.ts
17. scripts/doc-freshness.ts
18. scripts/harness-check.sh (하네스 자가진단)
```
(앞 1-12번은 그대로. 13번 설명 갱신 + 14번 신규 + 이후 1씩 재번호.)

- [ ] **Step 2: §12.2 파일별 분류 테이블 — HARNESS_FRICTION.md를 managed로 통일 + jsonl data 추가**

> 자체 검토 FIX: harness-scaffold §10.1과 일치하도록 `docs/HARNESS_FRICTION.md`를 `managed`로 통일(드래프트의 `data` 유지안을 교정).

Old:
```
| 22 | `docs/HARNESS_FRICTION.md` | data | session-routine이 마찰 이벤트 기록 |
```
New:
```
| 22 | `docs/HARNESS_FRICTION.md` | managed | 정적 참조 문서(이벤트 유형/심각도 참조표 + 이슈 보고 안내). 템플릿 기반, 로그 테이블 없음 |
| 26 | `.harness-friction.jsonl` | data | 마찰 이벤트 자동 기록 싱크(append-only JSONL). 템플릿 해시 드리프트 검사 제외 — feature_list와 동일 취급 |
```

- [ ] **Step 3: §10 향후 확장 — 피드백 분석 스킬 입력원 정정**

Old:
```
- **피드백 분석 스킬** (`companion-skills/harness-feedback/`): HARNESS_FRICTION.md 마찰 로그를 분석하여 반복 패턴을 식별하고, harness-setup 리포에 GitHub Issue를 자동 생성
```
New:
```
- **피드백 분석 스킬** (`companion-skills/harness-feedback/`): `.harness-friction.jsonl`에 자동 기록된 마찰 이벤트를 분석하여 반복 패턴을 식별하고, harness-setup 리포에 GitHub Issue를 자동 생성
```

- [ ] **Step 4: 검증**

Run: `grep -nE '\.harness-friction\.jsonl' SKILL.md && grep -n '| 22 | `+"`docs/HARNESS_FRICTION.md`"+` | managed' SKILL.md && echo OK`
Expected: jsonl 3곳(Step5 14번 · §12.2 26번 · §10), 22번 managed 1건, `OK`.

- [ ] **Step 5: Commit**

```bash
git add SKILL.md
git commit -m "feat(skill): 분석 스킬 계약 동기화 — .harness-friction.jsonl managed 데이터 파일 (이슈 #9)"
```

---

### Task 5: harness-feedback/SKILL.md — 입력을 jsonl로 + 관용 파싱 + escape

**Files:**
- Modify: `companion-skills/harness-feedback/SKILL.md`

- [ ] **Step 1: 프론트매터 description 입력원 정정**

Old: `description: "하네스 마찰 로그(docs/HARNESS_FRICTION.md)를 분석하여 ...`
New: `description: "하네스 마찰 로그(.harness-friction.jsonl)를 분석하여 ...` (나머지 문구 동일)

- [ ] **Step 2: §1 마찰 로그 읽기 — jsonl cat으로 교체**

Old:
```
## 1. 마찰 로그 읽기

​```!
if [ -f docs/HARNESS_FRICTION.md ]; then
  cat docs/HARNESS_FRICTION.md
else
  echo "FRICTION_LOG_NOT_FOUND"
fi
​```

위 출력이 `FRICTION_LOG_NOT_FOUND`이면:
"`docs/HARNESS_FRICTION.md`가 없습니다. 하네스가 셋업된 프로젝트에서 실행하세요." 출력 후 **즉시 종료**한다.
```
New:
```
## 1. 마찰 로그 읽기

마찰 이벤트는 프로젝트 루트의 `.harness-friction.jsonl`(append-only, 한 줄 = 1 이벤트)에 자동 기록된다. 이 파일을 입력으로 읽는다.

​```!
if [ -f .harness-friction.jsonl ]; then
  cat .harness-friction.jsonl
else
  echo "FRICTION_LOG_NOT_FOUND"
fi
​```

위 출력이 `FRICTION_LOG_NOT_FOUND`이면:
"`.harness-friction.jsonl`이 없습니다. 하네스가 셋업된 프로젝트에서 실행하세요." 출력 후 **즉시 종료**한다.
```

- [ ] **Step 3: §3 이벤트 파싱 — 줄 단위 JSON + 관용 파싱**

Old:
```
## 3. 이벤트 파싱

§ 1에서 읽은 마찰 로그의 `## 로그` 테이블에서 행을 추출한다.

각 행의 구조: `| 날짜 | 이벤트 | 심각도 | feature | 상세 |`

빈 테이블(행이 없음)이면:
"마찰 로그에 기록된 이벤트가 없습니다." 출력 후 **즉시 종료**한다.
```
New:
```
## 3. 이벤트 파싱

§ 1에서 읽은 `.harness-friction.jsonl`을 **줄 단위**로 파싱한다. 각 줄은 하나의 JSON 객체이며, 다음 필드를 가진다:

​```json
{"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-a3f9","event":"implementer-retry","severity":"high","feature":"F-12","detail":"타입 에러 3회 반복"}
​```

| 필드 | 의미 |
|------|------|
| `ts` | 이벤트 발생 시각 (ISO8601 UTC) |
| `session` | 세션 고유 ID — 형식 `{ISO 시각}-{4자 난수}` (예: `2026-06-16T09-12-03Z-a3f9`) |
| `event` | 이벤트 유형 enum |
| `severity` | `low` \| `medium` \| `high` \| `critical` |
| `feature` | feature ID 또는 `""` |
| `detail` | 소독된 원인 한 줄 (≤50자) |

### 관용 파싱 (깨진 줄 격리)

- 빈 줄은 무시한다.
- 각 줄을 JSON으로 파싱하되, **파싱에 실패한 줄은 건너뛴다.** 깨진 한 줄이 전체 분석을 죽이지 않는다.
- 건너뛴 줄의 개수를 세어 두고, § 4 분석 결과와 § 6 사용자 확인 시 함께 보고한다(예: "파싱 실패로 건너뛴 줄: {M}개").
- 파싱에 성공한 줄들만 § 4 패턴 분석의 입력으로 삼는다.

파싱에 성공한 이벤트가 0건이면(파일은 존재하나 유효한 줄이 없음):
"기록된 이벤트가 없습니다." 출력 후 **즉시 종료**한다.
```

- [ ] **Step 4: §4 빈 패턴 종료 메시지에 스킵 수 보고 추가**

Old:
```
보고 대상 패턴이 없으면:
"보고 기준을 충족하는 패턴이 없습니다. critical 이벤트 1회 이상, 또는 동일 이벤트 2회 이상이 기준입니다." 출력 후 **즉시 종료**한다.
```
New:
```
보고 대상 패턴이 없으면:
"보고 기준을 충족하는 패턴이 없습니다. critical 이벤트 1회 이상, 또는 동일 event 2회 이상이 기준입니다." (§ 3에서 파싱 실패로 건너뛴 줄이 있으면 "파싱 실패로 건너뛴 줄: {M}개"도 함께 보고) 출력 후 **즉시 종료**한다.
```

- [ ] **Step 5: §5 이슈 본문 — 테이블 필드명 jsonl 정합 + detail escape 절 추가**

Old (이슈 형식 코드블록 `**Title**: [Friction] {이벤트 유형}: ...` ~ `... "마찰 로그의 상세 필드를 참고하세요." 기재}` ​```` 닫음까지):
교체 New:
```
​```markdown
**Title**: [Friction] {event}: {패턴 요약}

**Labels**: friction

**Body**:
## 마찰 패턴

- **이벤트**: {event}
- **발생 횟수**: {N}회
- **심각도**: {최고 severity}

## 이벤트 목록

| ts | session | feature | detail |
|------|---------|---------|--------|
{해당 이벤트 행들 — 각 줄의 ts·session·feature·detail 값}

## 환경 정보

- Node: {버전}
- 프로젝트: {package.json name}
- 하네스 버전: {manifest version}
- 생성일: {manifest generatedAt}

## 재현 맥락

{이벤트의 detail 필드에서 공통 맥락 추출. 추출이 어려우면 "각 이벤트의 detail 필드를 참고하세요." 기재}
​```

### detail escape (md 테이블 안전)

이벤트 목록 테이블의 셀에 `detail`(및 다른 필드) 값을 넣을 때, 마크다운 테이블이 깨지지 않도록 escape한다:

- 파이프 `|` → `\|`
- 줄바꿈(LF/CR) → 공백 한 칸

(오케스트레이터가 § 6.1 소독으로 1차 정리하지만, 소비 측에서도 방어적으로 escape한다.)
```

- [ ] **Step 6: 검증**

Run: `grep -nE 'harness-friction\.jsonl|줄 단위|건너뛴|\\\|' companion-skills/harness-feedback/SKILL.md && ! grep -nE 'docs/HARNESS_FRICTION\.md|## 로그' companion-skills/harness-feedback/SKILL.md && echo OK`
Expected: jsonl·줄 단위·건너뛴·escape 매치, docs/HARNESS_FRICTION.md·`## 로그` 0건, `OK`. allowed-tools(`Bash(cat *) Bash(echo *)`)는 변경 없음 확인.

- [ ] **Step 7: Commit**

```bash
git add companion-skills/harness-feedback/SKILL.md
git commit -m "feat(skill): harness-feedback 입력을 jsonl로 전환 + 관용 파싱 (이슈 #9)"
```

---

### Task 6: harness-checklist.md + harness-check.sh — 필수 managed 파일 추가

**Files:**
- Modify: `references/harness-checklist.md`
- Modify: `templates/harness-check.sh`

- [ ] **Step 1: harness-checklist.md §1.1 필수 파일 목록에 추가**

Old:
```
- [ ] `feature_list.json` — 기능 목록 + passes 상태
- [ ] `init.sh` — 환경 초기화 스크립트
```
New:
```
- [ ] `feature_list.json` — 기능 목록 + passes 상태
- [ ] `.harness-friction.jsonl` — 마찰 자동 기록 싱크 (append-only JSONL, manifest category `data`)
- [ ] `init.sh` — 환경 초기화 스크립트
```

- [ ] **Step 2: harness-checklist.md §1.1 검증 방법 명령 정합**

Old: `**검증 방법**: `+"`ls AGENTS.md ARCHITECTURE.md claude-progress.txt feature_list.json init.sh docs/`"
New: `**검증 방법**: `+"`ls AGENTS.md ARCHITECTURE.md claude-progress.txt feature_list.json .harness-friction.jsonl init.sh docs/`"

- [ ] **Step 3: harness-check.sh ① 필수 파일 for 루프에 추가**

Old:
```
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt \
         feature_list.json init.sh scripts/structural-test.ts scripts/doc-freshness.ts; do
```
New:
```
for f in AGENTS.md ARCHITECTURE.md CLAUDE.md claude-progress.txt \
         feature_list.json .harness-friction.jsonl init.sh scripts/structural-test.ts scripts/doc-freshness.ts; do
```

- [ ] **Step 4: 검증**

Run: `grep -n '\.harness-friction\.jsonl' references/harness-checklist.md templates/harness-check.sh && echo OK`
Expected: harness-checklist.md 2건(목록 + ls 명령), harness-check.sh 1건(for 루프), `OK`.

- [ ] **Step 5: Commit**

```bash
git add references/harness-checklist.md templates/harness-check.sh
git commit -m "feat(refs): 필수 managed 파일에 .harness-friction.jsonl 추가 (이슈 #9)"
```

---

### Task 7: 릴리스 — version 범프 + 트래킹 + 이슈 클로즈

**Files:**
- Modify: `SKILL.md:550`, `harness-scaffold/SKILL.md:77`, `.tracking/TODO.md`, `.tracking/CHANGELOG.md`, `.tracking/HANDOFF.md`, `references/project-context.md`, `references/versioning-policy.md`

- [ ] **Step 1: 프로필 스키마 version 범프 (두 곳, byte-identical)**

`SKILL.md` L550: `  "version": "1.17.0",` → `  "version": "1.18.0",`
`harness-scaffold/SKILL.md` L77: `  "version": "1.17.0",` → `  "version": "1.18.0",`

- [ ] **Step 2: TODO.md — TODO-84 완료 표시**

`### TODO-84` 항목 전체(L670-674)를 다음으로 교체(완료 + 결정/해결 요약). [전체 newText는 드래프트 7-tracking edit#1 참조 — 상태 `[x] 완료 (2026-06-16, 1.18.0 — 이슈 #9 닫기)`, 결정(옵션 i), 해결 5단계 ①~⑤, 설계 정본 경로 포함].

- [ ] **Step 3: CHANGELOG.md — [1.18.0] 신규 섹션 삽입**

`---`⏎`## [1.17.0] — 2026-06-16 (E2E 모듈 마감 ...)` 직전에 `## [1.18.0] — 2026-06-16 (마찰 자동 기록 — 저비용 JSONL 싱크, 이슈 #9, TODO-84)` 섹션 삽입 (Added/Changed/비고 — 드래프트 7-tracking edit#2 전체 newText 사용). 기존 [미출시] 섹션은 손대지 않는다.

- [ ] **Step 4: HANDOFF.md — 현재 버전·세션·다음 후보 갱신**

(a) `**현재 버전: 1.17.0** ...` → `**현재 버전: 1.18.0** (마찰 자동 기록 — 저비용 JSONL 싱크, 이슈 #9, TODO-84)`
(b) 세션 목록 최상단(`- **Session 43 (06-16)**` 직전)에 `- **Session 44 (06-16)**: 1.18.0 — 마찰 자동 기록 ...` 엔트리 추가 (드래프트 7-tracking edit#5 전체).
(c) `**▶ 즉시 다음 후보**` 도입 문장을 갱신 — `이슈 #9/TODO-84 마찰 자동 기록은 1.18.0에서 종결·닫힘` + `남은 구현 항목은 TODO-85(...)만 미해결` 반영 (드래프트 7-tracking edit#3 전체).

- [ ] **Step 5: project-context.md — 버전 히스토리 1.18.0 + 1.7.1 후행 주석**

(a) `### 1.17.0 (E2E 모듈 마감 ...)` 직전에 `### 1.18.0 (마찰 자동 기록 ...)` 항목 추가 (드래프트 7-tracking edit#6 전체 — 배경·데이터 모델·설계 결정 옵션 i 자문 종합 포함).
(b) `- 열린 이슈 5건을 1.7.0 기준 대조 — 해결 2건 ... 등록(TODO-84~86)` 줄 끝에 `. 이후 TODO-86은 1.8.0(이슈 #4), TODO-84는 1.18.0(이슈 #9)으로 종결, TODO-85(이슈 #6 인프라 트랙)만 미해결로 남음` 추가.

- [ ] **Step 6: versioning-policy.md §7 예시표에 1.18.0 행 추가 (GAP B)**

`| 1.17.0 릴리스 | ... | MINOR | ... |` (L225) 직후에 삽입:
```
| 1.18.0 릴리스 | 마찰 자동 기록(이슈 #9, TODO-84): `.harness-friction.jsonl` 새 managed 데이터 싱크 + session-routine 마찰 기록을 JSONL append로 교체 + HARNESS_FRICTION.md 정적 격하 + harness-feedback jsonl 파싱. 빈 파일 자동 생성·하위 호환·마이그레이션 불필요. | MINOR | 새 managed 데이터 파일 + 생성/소비 경로 변경 — 기존 하네스 호환 |
```

- [ ] **Step 7: 정합성·골든 픽스처 회귀 검증**

Run:
```bash
cd /Users/daehyun/.claude/skills/harness-setup
grep -c '"version": "1.18.0"' SKILL.md harness-scaffold/SKILL.md
grep -n '\[1.18.0\]' .tracking/CHANGELOG.md
grep -n '현재 버전: 1.18.0' .tracking/HANDOFF.md
grep -n '### 1.18.0' references/project-context.md
grep -n '1.18.0 릴리스' references/versioning-policy.md
grep -n '\[x\] 완료 (2026-06-16, 1.18.0' .tracking/TODO.md
bash test/run-fixtures.sh
```
Expected: 각 grep 1건 이상 매치 + `run-fixtures.sh`가 3 아키텍처 pass/fail 전부 통과(템플릿 회귀 없음).

- [ ] **Step 8: 커밋 + 태그 + 이슈 클로즈** (사용자 확인 후 — `/gc` 사용 권장)

```bash
git add SKILL.md harness-scaffold/SKILL.md .tracking/ references/
git commit -m "docs(tracking,skill): 1.18.0 — 마찰 자동 기록 마감 + TODO-84 종결 (이슈 #9)"
git tag -a v1.18.0 -m "마찰 자동 기록 — 저비용 JSONL 싱크 (이슈 #9, TODO-84)"
gh issue close 9 --comment "1.18.0에서 마찰 자동 기록(.harness-friction.jsonl JSONL 싱크) 구현으로 종결. 설계: .tracking/specs/2026-06-16-friction-auto-logging-design.md"
```

---

### Task 8: 스캐폴드 스모크 테스트 (수동 — 실동작 검증)

**Files:** (읽기/실행만 — 소스 변경 없음)

- [ ] **Step 1: `_sandbox` 픽스처에 스캐폴드** — 기존 `_sandbox/vite-spa` 또는 신규 픽스처에서 2-스킬 플로우 실행(또는 직접 harness-scaffold 호출). `.harness-friction.jsonl`이 **빈 파일**로 생성되는지 확인:
Run: `ls -la _sandbox/<fixture>/.harness-friction.jsonl && wc -c _sandbox/<fixture>/.harness-friction.jsonl`
Expected: 파일 존재, 0 바이트.

- [ ] **Step 2: append 스모크** — 정본 스키마 한 줄을 수동 append:
```bash
echo '{"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-test","event":"implementer-retry","severity":"high","feature":"F-1","detail":"smoke"}' >> _sandbox/<fixture>/.harness-friction.jsonl
```

- [ ] **Step 3: 깨진 줄 격리 스모크** — 일부러 잘못된 JSON 한 줄 추가:
```bash
echo '{"ts":"bad" broken json |' >> _sandbox/<fixture>/.harness-friction.jsonl
```

- [ ] **Step 4: harness-feedback 관용 파싱 확인** — 해당 픽스처에서 "하네스 피드백 분석해줘" 실행. 정상 줄 1건을 분석하고 깨진 줄 1건을 "파싱 실패로 건너뛴 줄: 1개"로 보고하는지 확인.
Expected: 빈 로그(dead-letter)가 아니라 implementer-retry 1건 인식 + 스킵 1건 보고.

- [ ] **Step 5: 정리** — 스모크용 픽스처 변경은 커밋하지 않는다(`_sandbox`는 gitignore). 결과를 `.tracking/HANDOFF.md` Session 44 엔트리에 "실동작 확인" 한 줄로 남긴다.

---

## 실행 자체 검토 결과 (이 플랜이 스펙을 빠짐없이 덮는가)

| 스펙 섹션 | 덮는 태스크 |
|----------|------------|
| §4.1 jsonl 스키마 | T1.S4, T2.S2, T3.S2, T5.S3 (필드명 동일) |
| §4.2 SESSION_ID | T1.S1 (생성), 전 태스크 참조 |
| §4.3 event enum | T1.S4, T2.S2 (참조표) |
| §5.1 빈 파일 생성 + data 등록 | T2.S1·S2·S3 |
| §5.2 오케스트레이터 append | T1.S2·S4 |
| §5.3 HARNESS_FRICTION.md 격하 | T3, T2.S2, §category T2.S3+T4.S2 |
| §5.4 harness-feedback jsonl | T5 |
| §6.1 detail 소독 | T1.S4 |
| §7 변경 파일 8종 | T1~T6 (전부), 카탈로그 GAP A=T2.S5, versioning-policy GAP B=T7.S6 |
| §9 능력 광고(always-on) | T2.S5 |
| §11 검증 계획 | T7.S7(골든 픽스처) + T8(스모크) |
| 버전 1.18.0 | T7.S1 (양쪽 byte-identical) |
