# E2E TDD 배선 (증분 2a) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 증분 1의 E2E 스캐폴드를 TDD 사이클에 배선한다 — RED가 명시적 판정과 함께 E2E 스펙을 작성하고, VERIFY(E2E)가 해당 feature E2E를 검증하며, Debugger가 브라우저 재현으로 진단한다.

**Architecture:** 기존 managed 템플릿 5개(agents 3 + rules 2) 텍스트만 편집한다. 신규 파일·git config·신규 플레이스홀더 0. 모든 변경은 SKILL.md §12.6 자동 감지로 전 하네스에 전파(비-e2e는 런타임 휴면) → 마이그레이션 불필요. 게이트 신호는 LLM 기억이 아니라 명시적 E2E 판정(Test Engineer Output) + TDD STATE 보존 + `@feature:{ID}` grep 키로 결정화한다.

**Tech Stack:** Markdown 템플릿(에이전트/룰 정의), Playwright(`--grep`), bash/grep 검증. 스택 비종속 하네스.

**검증 방식(코드 TDD 대체):** 이 작업은 프로즈/템플릿 편집이라 단위 테스트가 없다. 각 태스크는 ① grep으로 현재 상태 확인(편집 전) → ② Edit 적용 → ③ grep으로 편집 반영 + **불변식(신규 `{{}}` 0개)** 확인 → ④ 커밋. 최종 태스크에서 정합성 검사(플레이스홀더 29 불변, 프로필 스키마 패리티, 골든 픽스처 회귀)를 일괄 실행한다.

**설계 정본:** `docs/superpowers/specs/2026-06-16-e2e-tdd-wiring-design.md`

---

## File Structure

| 파일 | 카테고리 | 책임 (2a 변경) |
|------|---------|---------------|
| `templates/rules/coding-standards.md` | managed | `@critical` 태그 정의 + 거버넌스 (어휘 기반) |
| `templates/agents/architect.md` | managed | E2E 슬롯 완성 — step→시나리오 매핑 + @critical 후보 표시 |
| `templates/agents/test-engineer.md` | managed | E2E 작성 심화(네이밍/태그/fixtures) + **E2E 판정 Output(필수)** |
| `templates/agents/debugger.md` | managed | E2E 실패 브라우저 재현 + 플레이키니스 환각 수정 금지 |
| `templates/rules/session-routine.md` | managed | VERIFY(E2E) Phase 4.7 + Agent Dispatch 행 + TDD STATE 필드 + `e2e-fail` 마찰 |
| `references/harness-checklist.md` | (참조) | §4.2에 E2E TDD 배선 구현 경로 명시 |
| `SKILL.md` · `harness-scaffold/SKILL.md` · `README.md` · 트래킹 | (혼합) | 1.12.0 버전 범프 + 정합성 검증 + 기록 |

의존 순서: 어휘(@critical) → 생산자(architect) → 작성자(test-engineer) → 진단(debugger) → 오케스트레이션(session-routine) → 참조/릴리스. 각 태스크는 독립 커밋.

---

## Task 1: coding-standards.md — @critical 태그 정의

**Files:**
- Modify: `templates/rules/coding-standards.md` (검증 레벨 섹션과 금지 사항 사이에 삽입)

- [ ] **Step 1: 현재 상태 확인 (@critical 미정의)**

Run: `grep -n "@critical" templates/rules/coding-standards.md`
Expected: 출력 없음 (아직 정의 안 됨)

- [ ] **Step 2: @critical 섹션 삽입**

`templates/rules/coding-standards.md`에서 검증 레벨 섹션의 마지막 줄과 금지 사항 헤더 사이에 새 섹션을 삽입한다.

old_string:
```
- feature_list.json의 steps는 **L4 E2E 테스트와 1:1 매핑** 가능해야 한다 (한 step = 검증 가능한 한 동작)
- 명령 값은 AGENTS.md의 "명령어" 섹션이 source of truth이다

## 금지 사항
```

new_string:
```
- feature_list.json의 steps는 **L4 E2E 테스트와 1:1 매핑** 가능해야 한다 (한 step = 검증 가능한 한 동작)
- 명령 값은 AGENTS.md의 "명령어" 섹션이 source of truth이다

## E2E @critical 태그

`@critical`은 E2E 스펙에 부여하는 태그로, **절대 깨지면 안 되는 핵심 사용자 흐름**(로그인, 결제, 데이터 손실 위험 동작 등)을 표시한다.

- Playwright 테스트 제목/어노테이션에 `@critical`을 넣고 `--grep @critical`로 필터한다.
- **pre-push 게이트 대상**이다 (강제 훅은 후속 증분 2b — 현재는 정의·작성 규율만 도입).
- **남용 금지**: pre-push 속도·신뢰를 보존하기 위해 진짜 핵심 흐름에만 부여한다. 모든 테스트에 붙이면 게이트가 무의미해진다.
- Reviewer가 `@critical` 과다 부여를 발견하면 자동 검사 승격 대기 큐(docs/TECH_DEBT.md)에 기록한다.

## 금지 사항
```

- [ ] **Step 3: 편집 반영 + 불변식 확인**

Run: `grep -c "@critical" templates/rules/coding-standards.md && grep -oE '\{\{[A-Z_]+\}\}' templates/rules/coding-standards.md | sort -u`
Expected: `@critical` 4회 이상 매칭. 플레이스홀더 목록은 편집 전과 동일(신규 `{{}}` 0개 — 이 파일엔 `{{ARCHITECTURE_TYPE}}`/`{{LAYER_RULES_SUMMARY}}`/`{{NAMING_RULES}}`/`{{PATH_ALIAS}}`만 존재해야 함).

- [ ] **Step 4: 커밋**

```bash
git add templates/rules/coding-standards.md
git commit -m "feat(templates): coding-standards @critical 태그 정의 (증분 2a)"
```

---

## Task 2: architect.md — E2E 슬롯 완성

**Files:**
- Modify: `templates/agents/architect.md:60` (Output Format의 테스트 전략 E2E 슬롯)

- [ ] **Step 1: 현재 상태 확인 (미완성 슬롯)**

Run: `grep -n "E2E:" templates/agents/architect.md`
Expected: `- E2E: {feature.steps 기반 시나리오, 해당 시}` (미완성)

- [ ] **Step 2: E2E 슬롯 완성**

old_string:
```
- E2E: {feature.steps 기반 시나리오, 해당 시}
```

new_string:
```
- E2E: {E2E 프레임워크 존재 + feature가 UI 상호작용이면, 각 step → E2E 시나리오 매핑 + @critical 후보(절대 깨지면 안 되는 핵심 흐름) 표시. 아니면 "해당 없음"}
```

- [ ] **Step 3: 편집 반영 확인**

Run: `grep -n "@critical 후보" templates/agents/architect.md`
Expected: 1줄 매칭. (이 파일엔 원래 플레이스홀더가 없으므로 신규 `{{}}` 0개 자명.)

- [ ] **Step 4: 커밋**

```bash
git add templates/agents/architect.md
git commit -m "feat(templates): architect E2E 슬롯 완성 (증분 2a)"
```

---

## Task 3: test-engineer.md — E2E 작성 심화 + E2E 판정 Output

**Files:**
- Modify: `templates/agents/test-engineer.md:19` (E2E 작성 지시 심화)
- Modify: `templates/agents/test-engineer.md` Output Format (E2E 판정 블록 추가)

- [ ] **Step 1: 현재 상태 확인 (판정 블록 부재)**

Run: `grep -n "E2E 판정\|@feature:" templates/agents/test-engineer.md`
Expected: 출력 없음

- [ ] **Step 2: line 19 E2E 작성 지시 심화**

old_string:
```
- feature.steps의 각 단계를 검증하는 테스트를 포함한다 — steps는 E2E 시나리오와 1:1 매핑되도록 작성되어 있으므로, E2E 프레임워크가 있으면 step당 E2E 케이스 1개를 작성하고, 없으면 가장 가까운 레벨의 테스트로 검증한다 (검증 레벨: .claude/rules/coding-standards.md 참조)
```

new_string:
```
- feature.steps의 각 단계를 검증하는 테스트를 포함한다 — steps는 E2E 시나리오와 1:1 매핑되도록 작성되어 있으므로, E2E 프레임워크가 있으면 step당 E2E 케이스 1개를 작성하고, 없으면 가장 가까운 레벨의 테스트로 검증한다 (검증 레벨: .claude/rules/coding-standards.md 참조)
  - **E2E 작성 규칙** (E2E 프레임워크 존재 + feature가 UI 상호작용일 때): 스펙은 `e2e/specs/{featureID}-{slug}.e2e.ts`로 작성하고 테스트 제목에 `@feature:{featureID}` 태그를 넣는다 — VERIFY(E2E)가 `--grep @feature:{featureID}`로 이 feature 스펙만 선택 실행한다. `e2e/fixtures/test.ts`의 base test(per-test fresh context)를 사용하고 `data-testid` 셀렉터를 우선한다. Architect가 표시한 @critical 후보 중 진짜 핵심 흐름에만 `@critical` 태그를 부여한다(남용 금지 — coding-standards.md 참조).
```

- [ ] **Step 3: Output Format에 E2E 판정 블록 추가**

old_string:
```
### 테스트 커버리지 의도
- {어떤 시나리오를 커버하는지 요약}
```

new_string:
```
### 테스트 커버리지 의도
- {어떤 시나리오를 커버하는지 요약}

### E2E 판정 (필수)
- status: created | skipped | not_applicable
- spec_paths: {작성한 .e2e.ts 경로 목록, 없으면 "없음"}
- critical: {@critical 부여한 경로/제목, 없으면 "없음"}
- reason: {판정 근거 — skipped/not_applicable일 때 필수}
```

- [ ] **Step 4: 판정 강제 규칙을 Instructions에 명시**

old_string:
```
### 4. 테스트가 이미 통과하는 경우
```

new_string:
```
### 3.5 E2E 판정 (침묵 금지)
RED 종료 시 Output의 "E2E 판정" 블록을 **반드시** 채운다. E2E가 적절한데 이번에 작성하지 않았다면 `status: created`가 아니라 `skipped`로 명시하고 reason을 적는다 — 판정을 비우거나 생략하면 VERIFY(E2E)가 BLOCK한다(침묵 = PASS 아님).

### 4. 테스트가 이미 통과하는 경우
```

- [ ] **Step 5: 편집 반영 + 불변식 확인**

Run: `grep -c "@feature:\|E2E 판정\|침묵 = PASS 아님" templates/agents/test-engineer.md && grep -oE '\{\{[A-Z_]+\}\}' templates/agents/test-engineer.md | sort -u`
Expected: 매칭 3건 이상. 플레이스홀더는 `{{TEST_COMMAND}}`만(신규 `{{}}` 0개). 참고: `{featureID}`·`{slug}`는 프로즈 안의 설명용 중괄호로 `{{...}}` 템플릿 플레이스홀더가 아니다.

- [ ] **Step 6: 커밋**

```bash
git add templates/agents/test-engineer.md
git commit -m "feat(templates): test-engineer E2E 작성 + 판정 Output (증분 2a)"
```

---

## Task 4: debugger.md — 브라우저 재현 모드

**Files:**
- Modify: `templates/agents/debugger.md` Input(아티팩트 추가) + Instructions(E2E 재현 서브섹션)

- [ ] **Step 1: 현재 상태 확인**

Run: `grep -n "브라우저 재현\|trace\|playwright-report" templates/agents/debugger.md`
Expected: 출력 없음

- [ ] **Step 2: Input에 Playwright 아티팩트 추가**

old_string:
```
- Implementer의 시도 이력 (이전 에러 + 시도한 수정)
- Architect의 구현 계획
```

new_string:
```
- Implementer의 시도 이력 (이전 에러 + 시도한 수정)
- Architect의 구현 계획
- (실패가 `.e2e.ts`일 때) Playwright 아티팩트 — `playwright-report/`, trace.zip, 스크린샷
```

- [ ] **Step 3: E2E 재현 서브섹션 삽입 (진단 프로토콜 앞)**

old_string:
```
## Instructions

### 1. 진단 프로토콜
```

new_string:
```
## Instructions

### 0. E2E 실패 진단 (브라우저 재현, 해당 시)
실패한 테스트가 `.e2e.ts`(Playwright E2E)이면 일반 진단 프로토콜에 앞서:
1. Playwright 아티팩트를 먼저 본다 — `playwright-report/`, trace.zip, 스크린샷.
2. 필요하면 `--headed` 또는 trace 뷰어로 재현한다.
3. **로직 실패 vs 플레이키니스(타이밍/네트워크/렌더 지연)를 명시적으로 판별한다.**
   - 플레이키니스로 판단되면 코드에 `sleep`·불필요한 비동기 지연을 추가하는 **환각 수정을 하지 않는다.** 근본 원인(셀렉터 대기 부재, 고정 시드 부재, auth/route-block 누락 등)을 RCA에 기록하고 Circuit Breaker를 따른다.
   - 로직 실패면 아래 일반 진단 프로토콜을 적용한다.

### 1. 진단 프로토콜
```

- [ ] **Step 4: 편집 반영 확인**

Run: `grep -c "브라우저 재현\|플레이키니스\|환각 수정" templates/agents/debugger.md`
Expected: 3건 이상. (이 파일 플레이스홀더는 `{{VALIDATE_COMMAND}}`만 — 신규 `{{}}` 0개.)

- [ ] **Step 5: 커밋**

```bash
git add templates/agents/debugger.md
git commit -m "feat(templates): debugger 브라우저 재현 모드 (증분 2a)"
```

---

## Task 5: session-routine.md — VERIFY(E2E) 배선

**Files:**
- Modify: `templates/rules/session-routine.md` — Agent Dispatch 행 / Phase 4.7 / 기능 완료 게이트 / TDD STATE / 마찰 이벤트 (5개 편집)

- [ ] **Step 1: 현재 상태 확인**

Run: `grep -n "VERIFY(E2E)\|e2e_status\|e2e-fail" templates/rules/session-routine.md`
Expected: 출력 없음

- [ ] **Step 2: Agent Dispatch 테이블에 VERIFY 행 추가**

old_string:
```
| Refactor | Simplifier | `agents/simplifier.md` | Reviewer가 NEEDS_REFACTOR 반환 시 |
| On-demand | Debugger | `agents/debugger.md` | validate {{MAX_IMPLEMENTER_ATTEMPTS}}회 실패 시 |
```

new_string:
```
| Refactor | Simplifier | `agents/simplifier.md` | Reviewer가 NEEDS_REFACTOR 반환 시 |
| Post-Verify | VERIFY(E2E) | (오케스트레이터 단계 — 에이전트 아님) | `e2e.enabled` AND Test Engineer E2E status=created |
| On-demand | Debugger | `agents/debugger.md` | validate {{MAX_IMPLEMENTER_ATTEMPTS}}회 실패 시 / E2E 실패 시 |
```

- [ ] **Step 3: Phase 4.7 VERIFY(E2E) 섹션 삽입 (Phase 4.5 SECURITY 이후, Phase 5 REFACTOR 앞)**

old_string:
```
**분기**:
- PASS → Complete
- BLOCK → Phase 3 (Green) 재진입 (보안 수정사항을 Implementer에 전달)

### Phase 5: REFACTOR (리팩터링, 조건부)
```

new_string:
```
**분기**:
- PASS → Complete
- BLOCK → Phase 3 (Green) 재진입 (보안 수정사항을 Implementer에 전달)

### Phase 4.7: VERIFY(E2E) (조건부)

REVIEW·SECURITY·(조건부 REFACTOR)가 모두 끝난 뒤, **기능 완료 직전**에 실행한다.

**게이트** (`profile.e2e.enabled`가 참일 때만 평가):
- Test Engineer E2E 판정이 `created` → 실행한다.
- `skipped` / `not_applicable` → VERIFY를 건너뛴다 (명시적 선언이 있어야만 스킵).
- 판정 유실/모호(재개 세션 등) → **BLOCK**: `e2e/specs`를 feature ID(`@feature:{featureID}`)로 재탐색하거나, 불명확하면 사용자에게 확인을 요청한다. 침묵은 PASS가 아니다.

**실행**: 해당 feature 스펙만 선택 실행한다(전체 스위트 아님) — `{{TEST_COMMAND}}` 계열 E2E 명령에 `--grep @feature:{featureID}`를 적용. (전체 @critical 게이팅은 증분 2b의 pre-push 책임.)

**분기**:
- PASS → 기능 완료 처리.
- FAIL(로직) → 마찰 로그 기록(`e2e-fail`) → Phase 3 (Green) 재진입, **시도 횟수 누적**(`{{MAX_IMPLEMENTER_ATTEMPTS}}` 한도 — NEEDS_FIX와 동일).
- FAIL(플레이키니스 의심) → Debugger 브라우저 재현(§ debugger.md 0번)으로 로직 실패 vs 플레이키니스 판별. 플레이키니스 확인 시 코드 환각 수정 금지 → 보고 후 Debugger Circuit Breaker(2회 → 사용자 에스컬레이션).

무한 루프는 기존 시도 한도 + Debugger Circuit Breaker가 차단한다 — VERIFY(E2E)는 독립 무한 재시도를 도입하지 않는다.

### Phase 5: REFACTOR (리팩터링, 조건부)
```

- [ ] **Step 4: 기능 완료 처리에 VERIFY 게이트 전제 추가**

old_string:
```
## 기능 완료 처리

TDD 사이클이 성공적으로 완료되면:
```

new_string:
```
## 기능 완료 처리

**전제**: `e2e.enabled`이고 Test Engineer E2E status=created이면, 완료 처리 전에 **Phase 4.7 VERIFY(E2E)를 통과**해야 한다(미통과·미판정이면 완료 처리를 중단).

TDD 사이클이 성공적으로 완료되면:
```

- [ ] **Step 5: TDD STATE 블록에 e2e 필드 + VERIFY phase 추가**

old_string:
```
=== TDD STATE ===
feature: {feature ID}
phase: {PRE-RED | RED | GREEN | REVIEW | SECURITY | REFACTOR}
attempt: {현재 시도 횟수}
plan_ref: {Architect 계획 요약 또는 exec-plan 경로 또는 .claude/plans/ 파일 경로}
=== END TDD STATE ===
```

new_string:
```
=== TDD STATE ===
feature: {feature ID}
phase: {PRE-RED | RED | GREEN | REVIEW | SECURITY | REFACTOR | VERIFY(E2E)}
attempt: {현재 시도 횟수}
plan_ref: {Architect 계획 요약 또는 exec-plan 경로 또는 .claude/plans/ 파일 경로}
e2e_status: {created | skipped | not_applicable | 미정}
e2e_spec_paths: {작성한 .e2e.ts 경로 목록 또는 없음}
=== END TDD STATE ===
```

- [ ] **Step 6: 마찰 로그 이벤트 테이블에 e2e-fail 추가**

old_string:
```
| `refactor-rollback` | Simplifier 2회 실패 → 롤백 시 | high |
| `session-incomplete` | TDD 사이클 미완료 상태로 세션 종료 시 | low |
```

new_string:
```
| `refactor-rollback` | Simplifier 2회 실패 → 롤백 시 | high |
| `e2e-fail` | VERIFY(E2E)가 FAIL 반환 시 | high |
| `session-incomplete` | TDD 사이클 미완료 상태로 세션 종료 시 | low |
```

- [ ] **Step 7: 편집 반영 + 불변식 확인**

Run: `grep -c "VERIFY(E2E)\|e2e_status\|e2e-fail" templates/rules/session-routine.md && diff <(grep -oE '\{\{[A-Z_]+\}\}' templates/rules/session-routine.md | sort -u) <(git show HEAD:templates/rules/session-routine.md | grep -oE '\{\{[A-Z_]+\}\}' | sort -u)`
Expected: 첫 grep ≥ 5건. diff 출력 없음(플레이스홀더 집합 불변 — 신규 `{{}}` 0개).

- [ ] **Step 8: 커밋**

```bash
git add templates/rules/session-routine.md
git commit -m "feat(templates): session-routine VERIFY(E2E) 배선 (증분 2a)"
```

---

## Task 6: harness-checklist.md — E2E TDD 배선 명시

**Files:**
- Modify: `references/harness-checklist.md:119` (§4.2 검증 레벨 구성)

- [ ] **Step 1: 현재 상태 확인**

Run: `grep -n "1:1로 매핑 가능한가" references/harness-checklist.md`
Expected: line 119 매칭

- [ ] **Step 2: TDD 배선 체크 항목 추가**

old_string:
```
- [ ] feature_list의 steps가 E2E 테스트와 1:1로 매핑 가능한가
```

new_string:
```
- [ ] feature_list의 steps가 E2E 테스트와 1:1로 매핑 가능한가
- [ ] (e2e 옵트인 시) E2E가 TDD 사이클에 배선됨 — RED(Test Engineer)가 `@feature:{ID}` 태그로 작성, VERIFY(E2E)(session-routine Phase 4.7)가 해당 feature 스펙 실행, Debugger가 브라우저 재현. L4의 구현 경로(harness-setup 증분 2a)
```

- [ ] **Step 3: 편집 반영 확인 + 커밋**

Run: `grep -c "TDD 사이클에 배선" references/harness-checklist.md`
Expected: 1건

```bash
git add references/harness-checklist.md
git commit -m "docs(refs): harness-checklist E2E TDD 배선 명시 (증분 2a)"
```

---

## Task 7: 1.12.0 버전 범프 + 정합성 검증 + 트래킹

**Files:**
- Modify: `SKILL.md:543`, `harness-scaffold/SKILL.md:77`, `README.md:3`
- Modify: `.tracking/CHANGELOG.md`, `references/project-context.md`, `.tracking/HANDOFF.md`, `.tracking/TODO.md`

- [ ] **Step 1: 정합성 검증 — 전체 플레이스홀더 29 불변**

Run: `git stash list; git diff HEAD~6 --stat -- templates/ references/ | tail -3; echo "--- 신규 플레이스홀더 검사 ---"; diff <(git show HEAD~6:templates -- 2>/dev/null; grep -rhoE '\{\{[A-Z_]+\}\}' templates/ | sort -u) <(grep -rhoE '\{\{[A-Z_]+\}\}' templates/ | sort -u)`
Expected: 2a 편집 후 `templates/`의 플레이스홀더 집합이 편집 전과 동일(신규 `{{}}` 0개). 차이가 있으면 설계 위반 — 중단하고 원인 조사.

> 참고: 정확한 비교는 `git show <증분2a-시작-커밋>^:` 기준. 시작 커밋 = Task 1 직전(`ecf6a22` = 스펙 커밋). 즉 `git show ecf6a22:templates/...` 대비. 실행 시 `BASE=ecf6a22` 기준으로 `for f in templates/rules/coding-standards.md templates/agents/architect.md templates/agents/test-engineer.md templates/agents/debugger.md templates/rules/session-routine.md; do diff <(git show $BASE:$f | grep -oE '\{\{[A-Z_]+\}\}' | sort -u) <(grep -oE '\{\{[A-Z_]+\}\}' $f | sort -u) && echo "$f OK"; done` 로 파일별 확인.

- [ ] **Step 2: 정합성 검증 — 프로필 스키마 패리티(구조 무변경)**

Run: `diff <(sed -n '/"version"/,/^}/p' SKILL.md) <(sed -n '/"version"/,/^}/p' harness-scaffold/SKILL.md) | head; echo "--- e2e 스키마 무변경 확인 ---"; git diff ecf6a22 -- SKILL.md harness-scaffold/SKILL.md`
Expected: 두 SKILL.md의 e2e 블록을 포함한 프로필 스키마는 2a에서 **구조 변경 없음**(아직 버전 필드도 미변경 상태). 출력은 기존 패리티 유지.

- [ ] **Step 3: 버전 필드 범프 (3개 파일)**

`SKILL.md`:
- old_string: `  "version": "1.11.0",`
- new_string: `  "version": "1.12.0",`

`harness-scaffold/SKILL.md`:
- old_string: `  "version": "1.11.0",`
- new_string: `  "version": "1.12.0",`

`README.md`:
- old_string: `> 현재 버전: **1.11.0** · 상세 이력: [`.tracking/CHANGELOG.md`](.tracking/CHANGELOG.md)`
- new_string: `> 현재 버전: **1.12.0** · 상세 이력: [`.tracking/CHANGELOG.md`](.tracking/CHANGELOG.md)`

- [ ] **Step 4: CHANGELOG 1.12.0 엔트리 추가**

`.tracking/CHANGELOG.md`의 `## [1.11.0]` 위(최상단 `---` 다음)에 삽입:
```
## [1.12.0] — 2026-06-16 (E2E TDD 배선 — 이슈 #12 증분 2a)

> 증분 1의 E2E 스캐폴드를 TDD 사이클에 배선. MINOR (managed 템플릿 편집 — 신규 파일·git config·플레이스홀더 0). 마이그레이션 불필요(§12.6 자동 감지 전파). 멀티모델 적대적 검증 반영.

### 추가 (Added) — Session 37 (2026-06-16)
- coding-standards.md: `@critical` 태그 정의 + 남용 거버넌스(reviewer 승격 큐)
- architect.md: E2E 슬롯 완성 — step→시나리오 매핑 + @critical 후보 표시
- test-engineer.md: E2E 작성 심화(`e2e/specs/{ID}-*.e2e.ts` + `@feature:{ID}` 태그 + fixtures/test.ts) + **E2E 판정 Output(created/skipped/not_applicable, 침묵=BLOCK)**
- debugger.md: E2E 브라우저 재현 모드(trace/--headed) + 플레이키니스 환각 수정 금지
- session-routine.md: VERIFY(E2E) Phase 4.7(해당 feature 스펙만 실행, FAIL→GREEN 시도 누적) + Agent Dispatch 행 + TDD STATE `e2e_status`/`e2e_spec_paths` 보존 + `e2e-fail` 마찰 이벤트
- harness-checklist §4.2: E2E TDD 배선 구현 경로 명시

### 수정 (Changed) — Session 37 (2026-06-16)
- 결정: (a) E2E 작성 주체 = Test Engineer 확장(신규 에이전트 아님), (b) pre-push = 무의존 git hook(증분 2b로 분리)
- 적대적 검증(codex/gemini): 게이트 신호를 LLM 기억 → 명시적 판정+TDD STATE+grep 키로 결정화, VERIFY 범위 축소(feature 스펙만), 증분 2 → 2a/2b 분할
- 프로필 스키마 version 1.11.0 → 1.12.0(두 SKILL.md 동기), README/HANDOFF 버전 표기 갱신

---
```

- [ ] **Step 5: project-context.md 버전 히스토리 + 설계 결정 추가**

`references/project-context.md`의 버전 히스토리에 1.12.0 줄, 설계 결정 섹션에 "증분 2 분할(2a/2b), 결정 (a)/(b), 게이트 결정화" 요약을 추가한다. (기존 1.11.0 엔트리 형식을 따른다.)

- [ ] **Step 6: HANDOFF.md + TODO.md 갱신**

- `HANDOFF.md`: 현재 버전 1.11.0 → 1.12.0, Session 37 완료 항목 추가, P7 커버리지 행에 "1.12.0: E2E TDD 배선(VERIFY Phase 4.7)" 추가, 우선순위 목록의 "즉시 다음"을 증분 2b로 갱신.
- `TODO.md`: TODO-95를 **TODO-95a(완료, 1.12.0)** / **TODO-95b(미착수 — pre-push 인프라, 설계 §8)**로 재분할. 95b에 적대적 자문이 짚은 9개 난제(공존성·PM·monorepo·탐지·eslint 마커·보안·멱등성·표준 판정·신규파일 마이그레이션)를 관찰 포인트로 기록.

- [ ] **Step 7: 골든 픽스처 회귀 확인 (구조 템플릿 무영향 검증)**

Run: `bash test/run-fixtures.sh && bash test/e2e-fixtures.sh`
Expected: 둘 다 통과(전부 PASS). 2a는 structural-test/e2e 스캐폴드 템플릿을 건드리지 않으므로 회귀 없음을 확인하는 안전망.

- [ ] **Step 8: harness-scaffold §5.10/§5.11 본문 대조**

Run: `grep -n "test-engineer\|E2E\|@critical\|VERIFY" harness-scaffold/SKILL.md | head -20`
Expected: §5.10(agents 생성)/§5.11(rules 생성)이 에이전트 프로즈를 열거하지 않고 "템플릿 기반 생성"만 기술하면 편집 불필요(확인만). 만약 E2E/판정 동작을 구체 열거하는 줄이 있으면 그 줄만 편집 대상 템플릿과 동기화한다.

- [ ] **Step 9: 릴리스 커밋 + 태그**

```bash
git add SKILL.md harness-scaffold/SKILL.md README.md .tracking/CHANGELOG.md references/project-context.md .tracking/HANDOFF.md .tracking/TODO.md
git commit -m "feat(skill,refs): 1.12.0 버전 범프 + 증분 2a 정합성 + 트래킹"
git tag v1.12.0
```

> push는 별도 `/gs push`로 사용자 확인 후 수행(이 계획은 push하지 않음).

---

## 실전 검증 (구현 후 권장 — 선택)

CLAUDE.md 테스트 절차에 따라 실제 프로젝트(예: e2e 옵트인된 haja-web-fe)에서 1.11.0 → 1.12.0 업그레이드를 실행하여 §12.6 자동 감지가 5개 managed 템플릿 변경을 전파하는지, harness:check가 "표준 하네스 가동"을 유지하는지 확인한다. 이는 별도 세션의 관찰 기록 태스크(TODO-51 프로세스)로, 코어 구현 태스크와 분리한다.

---

## Self-Review

**1. 스펙 커버리지** (설계 §3~§7 대조):
- §3.1 명시적 E2E 판정 → Task 3 Step 3·4 ✅
- §3.2 침묵=BLOCK → Task 3 Step 4 + Task 5 Step 3(Phase 4.7 게이트) ✅
- §3.3 feature↔E2E grep 키 → Task 3 Step 2 + Task 5 Step 3 ✅
- §3.4 TDD STATE 보존 → Task 5 Step 5 ✅
- §4 VERIFY(E2E) Phase 4.7 + 범위 축소 + 시도 한도 + e2e-fail → Task 5 Step 3·4·6 ✅
- §5.1 architect 슬롯 → Task 2 ✅ / §5.2 test-engineer → Task 3 ✅ / §5.3 debugger → Task 4 ✅
- §6 @critical 정의·거버넌스 → Task 1 ✅
- §7 불변식(신규 파일/플레이스홀더/git config 0, 마이그레이션 불필요) → Task 7 Step 1·2·3, 버전 범프 ✅
- §9 harness-checklist → Task 6 ✅ / §9 harness-scaffold §5.10·5.11 대조 → Task 7 Step 8 ✅

**2. 플레이스홀더 스캔:** 계획 내 "TBD/적절히 처리/나중에" 없음. 모든 Edit이 정확한 old/new 문자열 포함 ✅. (`{featureID}`/`{slug}`는 생성 프로즈의 설명용 중괄호로 의도된 것 — Task 3 Step 5에서 `{{}}` 템플릿 플레이스홀더와 구분 명시.)

**3. 타입/명칭 일관성:** `@feature:{featureID}`(grep 키), `@critical`(태그), `e2e_status`/`e2e_spec_paths`(TDD STATE), `e2e-fail`(마찰 이벤트), `status: created|skipped|not_applicable`(판정값) — Task 1·3·5 전반에서 동일 표기 ✅. VERIFY(E2E) Phase 번호는 4.7로 통일(Task 5 Step 2·3·4, Task 6) ✅.
