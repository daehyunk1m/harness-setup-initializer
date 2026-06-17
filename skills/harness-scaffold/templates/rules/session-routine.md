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
| Post-Green | Security Reviewer | `agents/security-reviewer.md` | feature.category가 {{SECURITY_CATEGORIES}}일 때 / (infra 트랙) 변경이 보안 표면(.env·secrets·auth/세션/토큰·provider 배선·CORS·쿠키)에 닿을 때 |
| Refactor | Simplifier | `agents/simplifier.md` | Reviewer가 NEEDS_REFACTOR 반환 시 |
| Post-Verify | VERIFY(E2E) | (오케스트레이터 단계 — 에이전트 아님) | `e2e.enabled` AND Test Engineer E2E status=created |
| On-demand | Debugger | `agents/debugger.md` | validate {{MAX_IMPLEMENTER_ATTEMPTS}}회 실패 시 / E2E 실패 시 / 인프라 트랙 통합 검증(빌드·부팅·실동작) 실패 시 |

> **인프라/설정 트랙 예외**: `feature.category`가 `infra`/`config`이고 § 인프라/설정 트랙 게이트를 통과하면 Architect(기계적 변경 시)·Test Engineer(유닛 RED)를 스킵하고 **Implementer → 통합 검증(빌드+실동작) → Reviewer**로 진행한다. **Reviewer는 필수(스킵 불가)**이며 분류 타당성을 독립 감사한다. **Security는 보안 표면(.env·secrets·auth/세션/토큰·provider 배선·CORS·쿠키)에 닿으면 category와 무관하게 필수**다. (상세: § 인프라/설정 트랙)

### Subagent 호출 방법

1. 해당 에이전트의 `.md` 파일을 읽는다
2. Input 섹션에 명시된 데이터를 수집한다
3. Agent tool로 subagent를 호출하며, 에이전트 정의와 입력 데이터를 프롬프트로 전달한다
4. Output Format에 맞는 결과를 받아 다음 단계로 진행한다

---

## 세션 시작

세션 시작 절차(Step 1~3)는 **5분 내 완료**를 목표로 한다. 더 오래 걸리면 하네스 문서가 부실한 것이다 — 마찰 로그(`doc-stale` 또는 `setup-mismatch`)에 기록한다.

### Step 1: 상태 복원
```
1. claude-progress.txt를 읽는다
2. "=== TDD STATE ===" 블록이 있으면 중단된 사이클을 이어받는다
3. git status로 미커밋 변경 확인 (있으면 사용자에게 알림)
4. git log --oneline -10으로 최근 커밋을 확인한다
5. TDD STATE 블록과 git 이력의 정합성 확인
```

### Step 1.5: 세션 ID 발급

세션마다 1회 고유 ID를 발급하고 claude-progress.txt에 기록한다. 이 세션의 모든 마찰 줄(§ 마찰 로그)이 동일 값을 참조하므로, `harness-feedback`이 같은 날 복수 세션을 구분해 그룹핑·패턴 분석할 수 있다.

```
1. claude-progress.txt에 이미 "SESSION_ID: "로 시작하는 줄이 있으면(재개 세션) 그 값을 그대로 사용한다
2. 없으면 ID를 1회 생성한다 — 형식: {ISO 시각}-{4자 난수}
   - 시각은 UTC, 콜론은 하이픈으로 치환 (파일명·줄 안전): 2026-06-16T09-12-03Z
   - 난수는 소문자 영숫자 4자: a3f9
   - 예: 2026-06-16T09-12-03Z-a3f9
3. claude-progress.txt에 "SESSION_ID: <값>" 한 줄을 기록한다
```

### Step 2: 작업 선택
```
1. feature_list.json에서 passes: false인 항목을 확인한다
2. 가장 높은 priority의 미완료 기능을 선택한다
3. 선택한 기능의 category, description, steps를 기록한다
4. category가 `infra`/`config`이면 § 인프라/설정 트랙으로(게이트 통과 시), 아니면 일반 TDD 사이클로 진행한다
```

**회귀 우선 규칙**: 작업 선택 또는 진행 중에 기존에 `passes: true`였던 기능이 깨진 것을 발견하면, 새 기능보다 **회귀 복구를 우선**한다. 해당 기능의 passes를 false로 되돌리고(notes에 회귀 사유 기록) 복구를 이번 작업으로 선택한다.

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

{{INTEGRATION_NOTES}}

---

## 인프라/설정 트랙

설정·배선·도구 작업처럼 **RED→GREEN 유닛 TDD가 부적합한 변경**을 위한 대체 경로다. 인프라 작업에 억지로 유닛 테스트를 만드는 것(통합 테스트에 가까움)과, 반대로 TDD를 통째로 건너뛰는 것(이슈 #6) 둘 다 방지한다.

### 적용 조건 — 남용 방지 게이트

다음을 **모두**(AND) 만족할 때만 이 트랙을 쓴다. 하나라도 불확실하면 일반 TDD 사이클을 쓴다(**모호 → TDD**). **조건 2(부정 테스트)가 조건 3에 우선한다** — 변경에 테스트 가능한 변환/매핑/계산이 섞여 있으면, 전체를 "의존성 통합/스캐폴딩"으로 묶더라도 *그 단위는 인프라가 아니다*(분리하여 TDD).

1. **사전 선언**: `feature_list.json`의 해당 항목 `category`가 `infra` 또는 `config`다 — 계획 시점에 선언되어 사용자가 검토할 수 있어야 한다. **구현 중(GREEN) 임의 재분류 금지** — 실패하는 테스트를 회피하려고 진행 중인 기능을 인프라로 강등하지 않는다.
2. **부정 테스트**: "이 변경이 추가하는 동작에 대해 **의미 있는 실패 테스트(유닛/E2E)를 작성할 수 있는가?**" — *있다면 인프라가 아니다.* 일반 TDD를 쓴다. (예: "장바구니 합계 계산" = 테스트 가능 → 기능 / "AuthProvider로 앱 래핑" = 배선 → 인프라.) 의존성 통합·스캐폴딩에서 새로 작성하는 코드가 입력→출력 변환·검증·계산을 포함하면 그 단위는 인프라가 아니다.
3. **변경 범위 한정**: 변경이 배선/설정/셋업에 한정된다 — provider·DI·context 배선, 빌드·도구·env·CI 설정, 의존성 통합, 파일시스템 설정(.gitignore·tsconfig·package.json), 스캐폴딩. 새 도메인/비즈니스 로직이나 사용자 표면 동작을 도입하지 않는다.

**자기판정에 대한 독립 검증**: 위 3조건은 에이전트 자기 선언이므로, 트랙 종료 시 **Reviewer가 분류 타당성(부정 테스트가 실제로 거짓이었는지)을 독립 감사**한다(아래 흐름 6 — 인프라 트랙에서 Reviewer는 스킵 불가). 자기판정만으로 검증 단계를 누적 스킵할 수 없다.

### 트랙 흐름 (RED→GREEN→REFACTOR 대체)

게이트를 통과하면:

1. **감사 기록 (필수)**: 인프라 트랙 진입을 두 곳에 기록한다 — (a) `claude-progress.txt`에 사람 가독용 1줄 `INFRA-TRACK: {feature ID} — {게이트 통과 사유}`, (b) `.harness-friction.jsonl`에 기계 가독 이벤트 `infra-track-entry`(§ 마찰 로그, severity `low`, detail=세 게이트 조건 판정 요지 소독본). append-only 싱크라 세션 요약 재작성에도 소실되지 않고, harness-feedback이 트랙 사용 빈도·오분류 패턴을 집계해 남용을 가시화한다.
2. **Architect**: Plan 모드로 설계됐거나 변경이 기계적이면 스킵. 아니면 경량 설계.
3. **Test Engineer (유닛 RED)**: **스킵** — 게이트 전제상 의미 있는 유닛 테스트가 없다. 단 `e2e.enabled`이고 변경에 사용자 표면이 있으면(인프라엔 드묾) E2E 규칙(test-engineer.md)을 따른다. **E2E smoke를 작성하지 않으면 TDD STATE `e2e_status`를 명시적으로 `not_applicable`로 기록한다**(침묵 금지 — 재개 시 Phase 4.7 BLOCK 회피).
4. **Implementer**: 변경을 적용한다.
5. **통합 검증 (필수 — RED→GREEN 대체 게이트)**:
   - `{{VALIDATE_COMMAND}}`(빌드+타입+린트+테스트)가 통과해야 한다.
   - **실동작 확인**: `init.sh`의 devServer readyCheck로 부팅을 확인하거나, 영향 받는 흐름을 1회 직접 실행해 배선이 동작함을 확인한다.
   - `e2e.enabled`이면 **영향 흐름 E2E smoke 1건을 권장**한다 — auth provider 등 load-bearing 배선이 실제로 도는지 확인(작성하면 Phase 4.7 VERIFY(E2E) 통과 대상, `e2e_status=created`).
   - 빌드/부팅/실동작 실패 → Debugger 에스컬레이션(§ Phase 3 GREEN의 검증 루프·에스컬레이션 경로 재사용, 시도 한도 동일).
6. **Reviewer (필수 — 인프라 트랙에서 스킵 불가)**: 인프라는 다파일 배선이라 오배선 위험이 크고, 자기판정 게이트의 유일한 독립 검증자다. **§ Phase 4 REVIEW의 "30줄 이하 단일 파일 스킵" 간소화는 인프라 트랙에 적용되지 않는다**(변경 파일이 2개 이상이거나 category가 infra/config이면 무조건 Reviewer — 파일 쪼개기 회피 차단). Reviewer 입력에 **"INFRA-TRACK 분류가 타당한가 — 부정 테스트가 실제로 거짓인지"** 검증을 명시 책무로 포함한다. 분류가 틀렸다(테스트 가능한 로직이었다)고 판단되면 NEEDS_FIX로 일반 TDD 경로로 되돌린다.
7. **Security Reviewer (보안 표면이면 필수)**: `feature.category`가 {{SECURITY_CATEGORIES}}이거나 **변경이 보안 표면에 닿으면 category와 무관하게(infra/config 포함) 반드시 실행**한다. **보안 표면**(기계적 판정 — 변경 경로/내용이 다음을 포함): 인증/세션/토큰 · `.env`/secrets/자격증명 · auth provider·미들웨어 배선 · CORS · 쿠키 · 권한. 모호하면 실행한다(디폴트 실행 — '모호 → TDD'와 대칭). 인프라라고 보안 리뷰를 건너뛰지 않는다(이슈 #6의 AuthProvider 배선이 정확히 이 경우다).
8. **완료 처리**: 통합 검증 통과 + Reviewer PASS (+ 보안 표면 시 Security PASS) → `feature_list.json` `passes: true`(§ 기능 완료 처리). E2E 스펙을 작성했다면 Phase 4.7 VERIFY(E2E)를 통과해야 한다.

### 다단계·다세션 인프라 작업

7-Phase 백엔드 연동처럼 여러 세션에 걸친 다단계 인프라 작업은 **Phase별 개별 infra 항목으로 feature_list.json에 분해**한다(예: `F-infra-0` 인증 통합, `F-infra-1` 데이터 레이어 …). 진행 상태는 별도 블록 없이 각 항목의 `passes`(완료=true/대기=false)·`priority`(순서)·`last_session`으로 표현한다("Phase 0 완료, Phase 1 대기"가 자연히 표현됨). 전체 설계 문서가 있으면 `docs/exec-plans/`에 두고 진행 중 사이클의 TDD STATE `plan_ref`로 참조한다.

중단/재개는 TDD STATE의 `track: infra`로 구분하며, phase는 기존 enum 값(GREEN/REVIEW/SECURITY)을 재사용한다(§ TDD STATE 블록).

---

## TDD 사이클

> **전체 사이클 스킵의 유일한 경로**: 아래 각 Phase의 '간소화'(Architect/Test Engineer/Reviewer 개별 스킵)는 **누적해서 전체 TDD를 우회하는 용도가 아니다.** 유닛 RED→GREEN 없이 기능을 완료하는 유일한 경로는 § 인프라/설정 트랙이며, 그 남용 방지 게이트를 통과해야 한다. 게이트를 통과하지 못하면 개별 간소화를 적용하더라도 RED→GREEN을 거친다.

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
    if attempt >= 2 → 마찰 이벤트 기록(implementer-retry) — § 마찰 로그 참조(.harness-friction.jsonl에 append)
    attempt += 1

if 실패:
    마찰 이벤트 기록(debugger-escalation) — § 마찰 로그 참조(.harness-friction.jsonl에 append)
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
    마찰 이벤트 기록(user-escalation) — § 마찰 로그 참조(.harness-friction.jsonl에 append)
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
- NEEDS_FIX → 마찰 이벤트 기록(review-fix) — § 마찰 로그 참조(.harness-friction.jsonl에 append) → Phase 3 (Green) 재진입 (시도 횟수 누적)

**자동 검사 승격 처리**: Reviewer Output에 "자동 검사 승격 후보"가 있으면 (Reviewer는 read-only이므로 기록은 오케스트레이터가 한다):
1. `docs/TECH_DEBT.md`의 "자동 검사 승격 대기 큐"에서 같은 규칙의 기존 행을 찾는다
2. 있으면 횟수 +1, 최근 지적일 갱신 / 없으면 새 행 추가
3. 횟수가 **2 이상**이 되면 자동 검사(ESLint 규칙, structural-test 확장, 테스트)로의 승격을 사용자에게 제안한다

기록 매핑 (Reviewer Output → 큐 테이블 컬럼):
```
규칙 → 지적 규칙 / 오늘 날짜 → 최근 지적일 / 현재 feature ID → 관련 feature
제안 검사 → 제안 검사 방법 / 상태 → "대기"로 시작, 승격 완료 시 "승격됨"
```

**간소화**: 30줄 이하 단일 파일 변경이면 Reviewer를 스킵 (validate만 의존). **단 § 인프라/설정 트랙에는 적용되지 않는다** — 인프라 트랙은 Reviewer가 분류 타당성 독립 감사를 겸하므로 스킵 불가.

### Phase 4.5: SECURITY (보안 리뷰, 조건부)

다음 중 하나면 실행한다:
- feature.category가 {{SECURITY_CATEGORIES}} 중 하나일 때, 또는
- (인프라/설정 트랙) 변경이 **보안 표면**에 닿을 때 — category와 무관. 보안 표면 = 인증/세션/토큰 · `.env`/secrets/자격증명 · auth provider·미들웨어 배선 · CORS · 쿠키 · 권한(변경 경로/내용 기준). 모호하면 실행한다(디폴트 실행).

**Security Reviewer 호출**:
- Input: 변경 파일 + feature 맥락
- Output: 판정 (PASS / BLOCK)

**분기**:
- PASS → Complete
- BLOCK → Phase 3 (Green) 재진입 (보안 수정사항을 Implementer에 전달)

### Phase 4.7: VERIFY(E2E) (조건부)

**번호는 4.7이지만, 실행 시점은 REVIEW·SECURITY·(조건부) REFACTOR가 모두 끝난 직후 · 기능 완료 직전이다** — 모든 성공 경로(REVIEW PASS / SECURITY PASS / REFACTOR PASS)가 수렴하는 마지막 게이트다. `기능 완료 처리`의 전제로도 재확인되므로 어느 경로로 와도 누락되지 않는다.

**게이트** (`profile.e2e.enabled`가 참일 때만 평가):
- Test Engineer E2E 판정이 `created` → 실행한다.
- `skipped` / `not_applicable` → VERIFY를 건너뛴다 (명시적 선언이 있어야만 스킵).
- 판정 유실/모호(재개 세션 등) → **BLOCK**: `e2e/specs`를 feature ID(`@feature:{featureID}`)로 재탐색하거나, 불명확하면 사용자에게 확인을 요청한다. 침묵은 PASS가 아니다.

**실행**: 해당 feature 스펙만 선택 실행한다(전체 스위트 아님) — E2E 러너 `{{E2E_COMMAND}}`에 `--grep @feature:{featureID}`를 적용한다(유닛 러너 `{{TEST_COMMAND}}`가 **아님** — `.e2e.ts`는 유닛 테스트 글롭에 수집되지 않아 유닛 러너로는 0개 실행되어 거짓 PASS가 된다). (전체 @critical 게이팅은 pre-push 훅의 책임.)

**분기**:
- PASS → 기능 완료 처리.
- FAIL(로직) → 마찰 이벤트 기록(`e2e-fail`) — § 마찰 로그 참조(.harness-friction.jsonl에 append) → Phase 3 (Green) 재진입, **시도 횟수 누적**(`{{MAX_IMPLEMENTER_ATTEMPTS}}` 한도 — NEEDS_FIX와 동일).
- FAIL(플레이키니스 의심) → Debugger 브라우저 재현(§ debugger.md 0번)으로 로직 실패 vs 플레이키니스 판별. 플레이키니스 확인 시 코드 환각 수정 금지 → 보고 후 Debugger Circuit Breaker(2회 → 사용자 에스컬레이션).

무한 루프는 기존 시도 한도 + Debugger Circuit Breaker가 차단한다 — VERIFY(E2E)는 독립 무한 재시도를 도입하지 않는다.

### Phase 5: REFACTOR (리팩터링, 조건부)

Reviewer가 NEEDS_REFACTOR를 반환했을 때만 실행.

**Simplifier 호출**:
- Input: Reviewer 소견 + 현재 구현
- Output: 리팩터링된 코드

**검증**: `{{VALIDATE_COMMAND}}` 실행
- PASS → Complete
- FAIL (2회) → 마찰 이벤트 기록(refactor-rollback) — § 마찰 로그 참조(.harness-friction.jsonl에 append) → 리팩터링 전부 되돌리고, un-refactored 코드로 Complete

---

## 기능 완료 처리

**전제**: `e2e.enabled`이고 Test Engineer E2E status=created이면, 완료 처리 전에 **Phase 4.7 VERIFY(E2E)를 통과**해야 한다(미통과·미판정이면 완료 처리를 중단). 또한 작업 중 **시각/레이아웃을 브라우저로 직접 확인**했다면(MCP 진단·수동 스크린샷 포함), 그 동작이 `.e2e.ts` 회귀 스펙으로 **코드화**되어 있어야 완료로 처리한다 — 1회 육안 확인은 회귀 가드가 아니므로, 미코드화 시 Test Engineer에게 스펙 작성을 요청한 뒤 완료한다.

TDD 사이클이 성공적으로 완료되면:

```
1. feature_list.json 업데이트:
   - passes: true
   - last_session: 오늘 날짜
   - notes: 구현 요약

2. claude-progress.txt:
   - TDD STATE 블록 제거 (사이클 완료)
   - 세션 요약 추가

3. git commit (git-workflow.md 규칙 참조):
   - "feat({scope}): {description} - {featureID}"
   - scope는 git-workflow.md의 커밋 스코프에서 선택
   - **커밋 실행 방식은 git-workflow.md § 자동 커밋 정책의 모드를 따른다** (off=제안만 / confirm=승인 후 / auto=자동). 단 위험 작업(force/reset/no-verify·대규모 변경·의존성)은 모드 무관 항상 제안만 한다 (git-workflow.md § 금지 사항)
```

---

## 세션 종료

```
1. {{VALIDATE_COMMAND}} 최종 실행
2. feature_list.json 상태 확인
3. claude-progress.txt 세션 요약 작성
4. 진행 중인 TDD 사이클이 있으면:
   - TDD STATE 블록 저장
   - 마찰 이벤트 기록(session-incomplete) — § 마찰 로그 참조(.harness-friction.jsonl에 append)
     (사이클 미완료로 종료될 때의 안전망 기록 — 종료 시점에 반드시 1줄 append)
4.2 의도 적재 — 이 세션의 `claude-progress.txt` `요구:` 줄 + 오작동 발화를 의도 줄로 증류해 `.harness-intent.jsonl`에 append (§ 의도 로그). 의도 발화 없으면 0줄(정상)
4.5 피드백 보고 트리거 — cursor 이후 미보고 마찰을 평가해 충족 시 한 줄 제안 (§ 피드백 보고 트리거)
5. 미커밋 변경이 있으면 git-workflow.md 규칙에 따라 커밋 (§ 자동 커밋 정책 모드: off=제안 / confirm=승인 후 / auto=자동):
   - TDD 사이클 완료: feat 커밋
   - 사이클 미완료: checkpoint 커밋 (chore({scope}): checkpoint — {상태})
   - 코드는 반드시 빌드 가능한 상태여야 한다
```

### 피드백 보고 트리거

세션 종료 시 `.harness-friction.jsonl`의 **cursor(`.harness-feedback-cursor`) 이후** 이벤트를 보고 기준으로 평가해, 충족하면 **한 줄 제안만** 출력한다(자동 실행·gh 호출 없음 — 무-훅·승인 없이 실행 금지 원칙). 보고하면 cursor가 전진하므로 다음 세션엔 재제안되지 않는다(nagware 방지). `infra-track-entry`(감사 마커)·`session-incomplete`(루틴 기록)는 마찰 카운트·기준에서 제외한다. jsonl 부재 시 스킵, cursor 부재 시 전체를 미보고로 평가한다.

기준은 harness-feedback 보고 기준과 **동일**(`critical≥1 OR 동일 event≥2 OR high≥2`)하되 **cursor 이후 누적 윈도우**에 적용한다 — 트리거↔보고 정합(제안=반드시 보고 가능). 누적 윈도우라 단일 세션 dedup 제약(같은 feature+event 1회)을 넘어 교차세션·다feature로 기준 달성이 가능하다.

```sh
node -e '
const fs=require("fs"), JL=".harness-friction.jsonl", CUR=".harness-feedback-cursor";
if(!fs.existsSync(JL)) process.exit(0);
const lines=fs.readFileSync(JL,"utf8").split("\n");
let processed=0;
if(fs.existsSync(CUR)){try{processed=JSON.parse(fs.readFileSync(CUR,"utf8")).processedLines||0}catch{}}
const SKIP=new Set(["infra-track-entry","session-incomplete"]);
let crit=0,high=0,med=0;const ev={};
for(let i=processed;i<lines.length;i++){
  const r=lines[i].trim(); if(!r) continue;
  let e; try{e=JSON.parse(r)}catch{continue}
  if(!e||SKIP.has(e.event)) continue;
  if(e.severity==="critical")crit++; else if(e.severity==="high")high++; else if(e.severity==="medium")med++;
  ev[e.event]=(ev[e.event]||0)+1;
}
const sameGe2=Object.values(ev).some(c=>c>=2);
if(crit>=1||sameGe2||high>=2){
  const n=crit+high+med;
  console.log("ℹ️ 미보고 마찰 "+n+"건 (critical "+crit+"·high "+high+"·medium "+med+") — \x27하네스 피드백 분석해줘\x27로 보고 권장 (글로벌 컴패니언)");
}
'
```

---

## TDD STATE 블록

중단된 사이클을 다음 세션에서 이어받기 위해 claude-progress.txt에 기록한다:

```
=== TDD STATE ===
feature: {feature ID}
track: {tdd | infra}
phase: {PRE-RED | RED | GREEN | REVIEW | SECURITY | REFACTOR | VERIFY(E2E)}
attempt: {현재 시도 횟수}
plan_ref: {Architect 계획 요약 또는 exec-plan 경로 또는 .claude/plans/ 파일 경로}
e2e_status: {created | skipped | not_applicable | 미정}
e2e_spec_paths: {작성한 .e2e.ts 경로 목록 또는 없음}
=== END TDD STATE ===
```

- `track`: 생략 시 `tdd`(일반 RED→GREEN 사이클). `infra`이면 § 인프라/설정 트랙으로 진행한다. **인프라 트랙은 별도 phase 이름을 만들지 않고 기존 enum 값을 재사용한다** — GREEN(= Implementer + 통합 검증 묶음, 통합 검증 실패는 GREEN 내부에서 처리) / REVIEW / SECURITY.
- 재개 세션이 `track` 필드 없는 구식 블록을 읽으면, 같은 feature ID의 `INFRA-TRACK` 감사 줄(claude-progress.txt) 또는 `infra-track-entry`(.harness-friction.jsonl)이 있는지 교차 확인해 `track`을 복원한다. 불일치/모호하면 사용자에게 확인한다(침묵을 `tdd`로 디폴트해 진행하지 않는다 — Phase 4.7의 "판정 유실 시 BLOCK"과 대칭).

- 사이클 완료 시 이 블록을 제거한다
- 세션 중단 시 현재 상태를 블록에 저장한다
- 다음 세션 시작 시 이 블록을 읽고 해당 phase부터 재개한다
- plan_ref가 `.claude/plans/` 경로를 가리키면 Plan 모드로 작성된 설계이다. RED/GREEN 단계에서 이 파일을 Architect 계획으로 참조한다.

---

## 마찰 로그

TDD 사이클 중 마찰 이벤트가 발생하면 `.harness-friction.jsonl`(프로젝트 루트, append-only)에 **소독된 JSON 한 줄을 append**한다. 무거운 마크다운 테이블 편집(읽기→탐색→삽입→재작성) 대신 단일 append이므로 부하 상황에서도 건너뛰지 않는다. 이렇게 쌓인 줄을 `harness-feedback`이 읽어 패턴을 분석한다.

**기록 방법** — 한 줄을 그대로 append한다(`>>`):
```
echo '{"ts":"2026-06-16T12:34:56Z","session":"<SESSION_ID>","event":"implementer-retry","severity":"high","feature":"F-12","detail":"<소독된 한 줄>"}' >> .harness-friction.jsonl
```

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
| `infra-track-entry` | 인프라/설정 트랙 진입 시(§ 인프라/설정 트랙 흐름 1) — **감사 마커**(마찰 아님). detail=세 게이트 조건 판정 요지 | low |

**규칙**:
- `.harness-friction.jsonl`이 없으면 append를 건너뛴다 (에러 아님 — 스캐폴드 시 빈 파일로 생성되지만, 비-하네스 환경 대비)
- 같은 feature의 같은 이벤트가 같은 세션(동일 SESSION_ID)에서 반복되면 첫 번째만 기록한다
- `detail`은 에러 메시지의 핵심 한 줄 또는 원인 요약을 위 소독 규칙으로 가공한 결과 (≤50자)
- 한 이벤트 = `>>`로 정확히 한 줄만 append (여러 줄 금지 — 관용 파서가 줄 단위로 읽는다)
- 보고 상태는 `.harness-feedback-cursor`(별도 파일, append-only jsonl 미변경)가 추적한다 — harness-feedback이 보고/무시 시 처리한 물리 줄 수까지 전진시키고, 세션 종료 트리거(§ 피드백 보고 트리거)가 그 이후만 평가한다.

---

## 의도 로그

세션 종료 시(§ 세션 종료 Step 4.2) 이 세션의 제품 의도·오작동 발화를 `.harness-intent.jsonl`(프로젝트 루트, append-only)에 **소독된 JSON 한 줄씩 append**한다. 입력은 `claude-progress.txt`의 `요구:` 줄 + 사용자의 오작동 설명이다(파생이지 중복작성 아님). 누적된 원장은 intent-distill이 `@feature` E2E와 대조해 `docs/INTENT_BACKLOG.md`로 증류한다('의도 정리').

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
| `encoded` | `{"prd":false,"e2e":false,"test":false}` — **항상 all-false, 비권위**(커버리지는 intent-distill이 INTENT_BACKLOG.md로 파생; distill 미갱신) |

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
