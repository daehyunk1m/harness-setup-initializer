# TDD 세션 루틴

이 프로젝트는 **TDD 기반 subagent 파이프라인**으로 기능을 구현한다.
각 기능은 Red → Green → Refactor 사이클을 따르며, 전문 에이전트가 각 단계를 담당한다.

---

## Agent Dispatch

기능 구현 시 Agent tool로 subagent를 호출한다. 각 에이전트의 프롬프트는 해당 `.md` 파일을 읽어서 사용한다.

| TDD 단계 | Agent | 파일 | 호출 조건 |
|----------|-------|------|----------|
| Pre-Red | Architect | `agents/architect.md` | 항상 |
| Red | Test Engineer | `agents/test-engineer.md` | 항상 |
| Green | Implementer | `agents/implementer.md` | 항상 |
| Post-Green | Reviewer | `agents/reviewer.md` | 항상 |
| Post-Green | Security Reviewer | `agents/security-reviewer.md` | feature.category가 {{SECURITY_CATEGORIES}}일 때 |
| Refactor | Simplifier | `agents/simplifier.md` | Reviewer가 NEEDS_REFACTOR 반환 시 |
| On-demand | Debugger | `agents/debugger.md` | validate {{MAX_IMPLEMENTER_ATTEMPTS}}회 실패 시 |

### Subagent 호출 방법

1. 해당 에이전트의 `.md` 파일을 읽는다
2. Input 섹션에 명시된 데이터를 수집한다
3. Agent tool로 subagent를 호출하며, 에이전트 정의와 입력 데이터를 프롬프트로 전달한다
4. Output Format에 맞는 결과를 받아 다음 단계로 진행한다

---

## 세션 시작

### Step 1: 상태 복원
```
1. claude-progress.txt를 읽는다
2. "=== TDD STATE ===" 블록이 있으면 중단된 사이클을 이어받는다
3. git status로 미커밋 변경 확인 (있으면 사용자에게 알림)
4. git log --oneline -10으로 최근 커밋을 확인한다
5. TDD STATE 블록과 git 이력의 정합성 확인
```

### Step 2: 작업 선택
```
1. feature_list.json에서 passes: false인 항목을 확인한다
2. 가장 높은 priority의 미완료 기능을 선택한다
3. 선택한 기능의 category, description, steps를 기록한다
```

### Step 3: 회귀 체크
```
1. {{VALIDATE_COMMAND}} 실행
2. PASS → TDD 사이클 시작
3. FAIL → Debugger 호출하여 회귀 수정 후 진행
```

---

## Plan 모드 통합

Claude Code의 `/plan` 모드로 기능 설계를 완료한 경우, Plan 모드는 **PRE-RED (Architect) 단계를 대체**한다.

### Plan 모드 감지

다음 조건이 모두 참이면 "Plan 모드 설계 완료" 상태이다:
1. `.claude/plans/` 디렉토리에 현재 기능과 관련된 plan 파일이 존재한다
2. 사용자가 Plan 모드를 승인(approve)했다
3. TDD STATE 블록이 없거나, phase가 PRE-RED이다

### Plan 모드 후 TDD 진입

Plan 모드 설계가 완료되었으면 **Architect를 스킵하고 바로 RED(Phase 2)로 진입**한다:
1. Plan 파일의 내용을 Architect 계획으로 간주한다
2. TDD STATE의 `plan_ref`에 Plan 파일 경로를 기록한다
3. Test Engineer에게 Plan 파일 내용을 Architect 계획 대신 전달한다
4. 이후 GREEN → REVIEW → Complete는 동일하게 진행한다

### Plan 모드에서도 필수인 단계

Plan 모드가 세션 시작 루틴(§ 세션 시작)을 대체하지는 않는다:
- **회귀 체크**(Step 3)는 RED 진입 전에 반드시 실행한다
- **feature_list.json 선택**(Step 2)은 Plan 승인 후 해당 기능을 선택한다
- **기능 완료 처리**(§ 기능 완료 처리)는 반드시 수행한다

---

## TDD 사이클

### Phase 1: PRE-RED (설계)

**Architect 호출**:
- Input: feature 정보 + ARCHITECTURE.md
- Output: 구현 계획

**간소화**: 사소한 변경(설정, 텍스트)이면 Architect를 스킵하고 바로 Red로.

**Plan 모드 연계**: `/plan` 모드로 설계가 완료되었으면 Architect를 스킵하고 바로 Red로. Plan 파일이 Architect 계획을 대체한다. (상세: § Plan 모드 통합)

### Phase 2: RED (테스트 작성)

**Test Engineer 호출**:
- Input: Architect 계획 + feature.steps
- Output: 실패하는 테스트 파일

**확인**: `{{TEST_COMMAND}}`으로 새 테스트가 FAIL하는지 확인.
- 이미 PASS → 기능이 이미 존재할 수 있음. feature_list.json의 해당 기능을 재검토한다.

**간소화**: 테스트 불가한 변경(타입만, 문서만)이면 Test Engineer를 스킵.

### Phase 3: GREEN (구현)

**Implementer 호출**:
- Input: 실패하는 테스트 + Architect 계획
- Output: 테스트를 통과시키는 구현

**검증 루프**:
```
attempt = 1
while attempt <= {{MAX_IMPLEMENTER_ATTEMPTS}}:
    Implementer 호출 (이전 에러 컨텍스트 포함)
    {{VALIDATE_COMMAND}} 실행
    if PASS → Review로 진행
    if attempt >= 2 → 마찰 로그 기록 (implementer-retry)
    attempt += 1

if 실패:
    마찰 로그 기록 (debugger-escalation)
    Debugger 에스컬레이션
```

**Debugger 에스컬레이션**:
```
debugger_attempt = 1
while debugger_attempt <= {{MAX_DEBUGGER_ATTEMPTS}}:
    Debugger 호출 (에러 + Implementer 시도 이력)
    {{VALIDATE_COMMAND}} 실행
    if PASS → Review로 진행
    debugger_attempt += 1

if 실패:
    마찰 로그 기록 (user-escalation)
    사용자에게 진단 보고서 제시
    TDD STATE를 claude-progress.txt에 저장
    세션 중단
```

### Phase 4: REVIEW (코드 리뷰)

**Reviewer 호출**:
- Input: git diff + Architect 계획 + ARCHITECTURE.md
- Output: 판정 (PASS / NEEDS_REFACTOR / NEEDS_FIX)

**분기**:
- PASS → Security 체크 (해당 시) → Complete
- NEEDS_REFACTOR → Phase 5 (Refactor)
- NEEDS_FIX → 마찰 로그 기록 (review-fix) → Phase 3 (Green) 재진입 (시도 횟수 누적)

**간소화**: 30줄 이하 단일 파일 변경이면 Reviewer를 스킵 (validate만 의존).

### Phase 4.5: SECURITY (보안 리뷰, 조건부)

feature.category가 {{SECURITY_CATEGORIES}} 중 하나일 때만 실행.

**Security Reviewer 호출**:
- Input: 변경 파일 + feature 맥락
- Output: 판정 (PASS / BLOCK)

**분기**:
- PASS → Complete
- BLOCK → Phase 3 (Green) 재진입 (보안 수정사항을 Implementer에 전달)

### Phase 5: REFACTOR (리팩터링, 조건부)

Reviewer가 NEEDS_REFACTOR를 반환했을 때만 실행.

**Simplifier 호출**:
- Input: Reviewer 소견 + 현재 구현
- Output: 리팩터링된 코드

**검증**: `{{VALIDATE_COMMAND}}` 실행
- PASS → Complete
- FAIL (2회) → 마찰 로그 기록 (refactor-rollback) → 리팩터링 전부 되돌리고, un-refactored 코드로 Complete

---

## 기능 완료 처리

TDD 사이클이 성공적으로 완료되면:

```
1. feature_list.json 업데이트:
   - passes: true
   - last_session: 오늘 날짜
   - notes: 구현 요약

2. claude-progress.txt:
   - TDD STATE 블록 제거 (사이클 완료)
   - 세션 요약 추가

3. git commit 제안 (git-workflow.md 규칙 참조):
   - "feat({scope}): {description} - {featureID}"
   - scope는 git-workflow.md의 커밋 스코프에서 선택
```

---

## 세션 종료

```
1. {{VALIDATE_COMMAND}} 최종 실행
2. feature_list.json 상태 확인
3. claude-progress.txt 세션 요약 작성
4. 진행 중인 TDD 사이클이 있으면:
   - TDD STATE 블록 저장
   - 마찰 로그 기록 (session-incomplete)
5. 미커밋 변경이 있으면 git-workflow.md 규칙에 따라 커밋 제안:
   - TDD 사이클 완료: feat 커밋
   - 사이클 미완료: checkpoint 커밋 (chore({scope}): checkpoint — {상태})
   - 코드는 반드시 빌드 가능한 상태여야 한다
```

---

## TDD STATE 블록

중단된 사이클을 다음 세션에서 이어받기 위해 claude-progress.txt에 기록한다:

```
=== TDD STATE ===
feature: {feature ID}
phase: {PRE-RED | RED | GREEN | REVIEW | SECURITY | REFACTOR}
attempt: {현재 시도 횟수}
plan_ref: {Architect 계획 요약 또는 exec-plan 경로 또는 .claude/plans/ 파일 경로}
=== END TDD STATE ===
```

- 사이클 완료 시 이 블록을 제거한다
- 세션 중단 시 현재 상태를 블록에 저장한다
- 다음 세션 시작 시 이 블록을 읽고 해당 phase부터 재개한다
- plan_ref가 `.claude/plans/` 경로를 가리키면 Plan 모드로 작성된 설계이다. RED/GREEN 단계에서 이 파일을 Architect 계획으로 참조한다.

---

## 마찰 로그

TDD 사이클 중 마찰 이벤트가 발생하면 `docs/HARNESS_FRICTION.md`의 로그 테이블에 행을 추가한다.

**기록 형식**:
```
| {YYYY-MM-DD} | {이벤트} | {심각도} | {feature ID} | {에러 메시지 또는 원인 한 줄} |
```

**이벤트 유형**:
| 이벤트 | 기록 시점 | 심각도 |
|--------|----------|--------|
| `implementer-retry` | Implementer 2회째 실패 시 | high |
| `debugger-escalation` | Implementer 한도 초과 → Debugger 호출 시 | critical |
| `user-escalation` | Debugger도 한도 초과 → 사용자 보고 시 | critical |
| `review-fix` | Reviewer가 NEEDS_FIX 반환 시 | medium |
| `refactor-rollback` | Simplifier 2회 실패 → 롤백 시 | high |
| `session-incomplete` | TDD 사이클 미완료 상태로 세션 종료 시 | low |

**규칙**:
- 파일이 없으면 기록을 건너뛴다 (에러 아님)
- 같은 feature의 같은 이벤트가 같은 세션에서 반복되면 첫 번째만 기록한다
- 상세 필드는 에러 메시지의 핵심 한 줄 또는 원인 요약 (50자 이내)
