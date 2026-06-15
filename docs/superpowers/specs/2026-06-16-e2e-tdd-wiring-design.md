# 설계: E2E TDD 배선 (이슈 #12 증분 2a)

> 작성일: 2026-06-16
> 출처 이슈: #12 — 하네스에 브라우저 테스트/디버깅 계층 추가
> 범위: 이슈 #12의 **증분 2a** (TDD 사이클 배선). 증분 2b(pre-push 인프라)는 § 8로 분리·보류.
> 목표 버전: **1.12.0** (MINOR)
> 전제: 증분 1(1.11.0, E2E 옵트인 스캐폴드 모듈) 완료. 설계 정본: `2026-06-15-e2e-scaffold-module-design.md`
> 검증: 멀티모델 적대적 자문(codex 결함 / gemini 대안·운영 / Claude 합성) — 아티팩트 `.claude/artifacts/consult/{codex,gemini}-*-2026-06-15T16-54.md`

---

## 1. 배경 & 동기

증분 1은 프론트엔드 프로젝트에 **실제로 동작하는 E2E 스캐폴드**(playwright.config.ts + e2e/ + test:e2e + @playwright/test devDep)를 옵트인으로 생성하는 능력을 채웠다. 그러나 생성된 E2E는 **TDD 사이클과 분리**되어 있다 — 에이전트 파이프라인은 E2E를 작성/실행/디버깅하는 일관된 경로가 없다.

증분 2a는 이 E2E를 **TDD 사이클에 배선**한다:
- RED 단계가 E2E 스펙을 명시적 판정과 함께 작성하고,
- REVIEW 이후 조건부 VERIFY(E2E) 단계가 해당 feature의 E2E를 검증하며,
- Debugger가 E2E 실패를 브라우저 재현으로 진단한다.

**증분 2(원안)에서 증분 2a로 축소한 이유** (적대적 자문 결론): 원안은 인프라 변경(pre-push git hook + git config) + 워크플로 변경(VERIFY 단계) + 에이전트 변경을 한 릴리스에 묶었다. gemini가 "실패 도메인이 다르다 — 인프라가 깨져 롤백하면 안전한 에이전트 변경까지 잃는다"고 지적했고, codex는 "현재 형태로는 배선 보장이 약하다"고 평가했다. 둘 다 분할을 지지하여 **2a(안전·신규 파일 0) / 2b(pre-push 인프라·고위험)**로 분리한다. 이슈 #12가 이미 4증분으로 쪼개진 점진주의와 일관.

---

## 2. 핵심 설계 결정 (헤드라인)

E2E를 TDD 사이클에 배선하되, **신규 파일 0 · git config 0 · 신규 플레이스홀더 0**으로 한다.

- **결정 (a) — E2E 스펙 작성 주체 = Test Engineer 확장** (신규 에이전트 아님). RED는 "실패 테스트를 먼저 쓰는" 단일 작성자 단계이고 `test-engineer.md:19`에 E2E 작성 지시가 이미 배선돼 있다. 7개 에이전트 불변(§5.10), RED 단일 작성자 유지, 새 게이트 0. (대안: 8번째 조건부 에이전트 → 불변식 파괴·RED 분기. 거부.)
- **모든 배선은 managed 템플릿 편집**으로 한다 → SKILL.md §12.6 자동 감지로 전 하네스에 전파, 마이그레이션 불필요. E2E 가이드는 비-e2e 프로젝트에선 **런타임 휴면**(에이전트가 "E2E 프레임워크 존재 시"를 자체 판정).

두 불변식 보존:
1. **비침습**: 소스/tsconfig/vitest.config/package.json 비수정. (2a는 어떤 파일도 신규 생성하지 않음 — 기존 managed 템플릿 텍스트만 수정.)
2. **결정적 매니페스트**: 신규 파일 0 → manifest.files 변경 없음. 편집된 managed 템플릿은 §12.6 4-상태 자동 감지로 전파.

---

## 3. 게이트 신호의 내구성 (적대적 자문 핵심 수정)

원안의 VERIFY(E2E) 게이트는 "RED가 이 feature의 `.e2e.ts`를 작성했는가"를 **LLM 런타임 기억**에 의존했다. codex·gemini가 모두 이를 최대 결함으로 지목:

- **codex**: TDD STATE 블록(`feature`·`phase`·`attempt`·`plan_ref`)이 E2E 산출 여부/경로를 보존하지 않음 → 재개 세션·Plan 모드·한 스펙이 여러 feature 커버 시 추적 불가. Test Engineer Output도 "작성한 테스트 파일 목록"만 요구하고 E2E 판정을 강제하지 않음.
- **gemini**: 컨텍스트 윈도우가 밀리면 에이전트가 "이미 했다고 가정"하고 VERIFY를 스킵할 위험.

**수정 (3대 결정적 신호)**:

### 3.1 명시적 E2E 판정 — Test Engineer Output Format 확장
Test Engineer는 RED 종료 시 다음 블록을 **반드시** 출력한다 (신규 플레이스홀더 아님 — Output Format 텍스트):
```markdown
### E2E 판정
- status: created | skipped | not_applicable
- spec_paths: [작성한 .e2e.ts 경로]
- critical: [@critical 부여한 경로/제목]
- reason: {판정 근거 — 특히 skipped/not_applicable일 때 필수}
```
- `created`: E2E 스펙을 작성함.
- `skipped`: E2E가 적절하나 이번엔 의도적으로 미작성(이유 명시).
- `not_applicable`: feature가 UI 상호작용이 아니라 E2E 불필요(이유 명시).

### 3.2 침묵 = BLOCK (PASS 아님)
VERIFY(E2E) 진입 시 E2E 판정이 **없거나 모호**하면(재개 세션에서 유실 등) **스킵하지 않고 BLOCK**한다 — `e2e/specs`를 feature ID로 재탐색하거나, 불명확하면 사용자에게 확인을 요청한다. 명시적 `skipped`/`not_applicable` 선언이 있어야만 VERIFY를 건너뛴다. (codex 권고 #2: 침묵은 PASS가 아니라 BLOCK.)

### 3.3 feature ↔ E2E 결정적 매핑
한 스펙이 어느 feature에 속하는지 결정적으로 식별하기 위해 **네이밍 규칙**을 둔다 (codex 권고 #3). Test Engineer는 **둘 다** 부여한다:
- 파일명에 feature ID 접두: `e2e/specs/{featureID}-{slug}.e2e.ts` (예: `F001-login.e2e.ts`) — 사람 탐색·1 feature 1 파일 규율용.
- 테스트 제목에 `@feature:{featureID}` 태그 — **선택의 기계 키**(authoritative).

VERIFY(E2E)는 **제목 태그를 기준으로** 해당 feature 스펙만 선택 실행한다: `playwright test --grep @feature:{featureID}` (전체 스위트 아님 — § 4.2). 파일명 접두는 보조 규율이며 선택 키가 아니다(모호성 제거 — 선택 메커니즘은 grep 단일).

### 3.4 TDD STATE 보존
재개 세션을 위해 TDD STATE 블록에 두 필드를 추가한다 (런타임 상태 파일 — 플레이스홀더 아님):
```
e2e_status: {created | skipped | not_applicable}
e2e_spec_paths: {경로 목록}
```
없으면 § 3.2의 보수적 재탐색/확인 경로로 진입.

---

## 4. VERIFY(E2E) 단계 (session-routine.md)

### 4.1 위치 & 게이트
REVIEW(Phase 4) · SECURITY(Phase 4.5) 이후, 기능 완료 처리 이전에 **조건부 Phase 4.7 "VERIFY(E2E)"** 신설.

진입 게이트:
- `profile.e2e.enabled`가 참, **AND**
- Test Engineer E2E 판정이 `created` → 실행.
- 판정이 `skipped`/`not_applicable` → VERIFY 스킵(명시적 선언).
- 판정 유실/모호 → § 3.2 BLOCK(보수적 재탐색/확인).

Agent Dispatch 테이블에 행 추가:
| TDD 단계 | 단계 | 호출 조건 |
|----------|------|----------|
| Post-Review | VERIFY(E2E) | `e2e.enabled` AND E2E status=created |

### 4.2 동작 — 해당 feature 스펙만 실행 (gemini 속도 우려 수용)
gemini 지적: E2E 전체 스위트를 매 사이클 돌리면 수 분 소요 + 플레이키니스 → 에이전트가 타이밍 실패를 로직 버그로 오인해 코드를 헤집는 환각 루프 위험.

→ VERIFY(E2E)는 **§ 3.3 매핑으로 선택된 이 feature의 스펙만** 실행한다 (전체 스위트 아님). 전체 @critical 게이팅은 증분 2b의 pre-push 책임.

### 4.3 결과 분기 (무한 루프 차단 — gemini 플레이키니스 우려 수용)
- **PASS** → 기능 완료 처리.
- **FAIL(로직)** → Phase 3(GREEN) 재진입(NEEDS_FIX와 동일), 마찰 로그 `e2e-fail` 기록, **시도 횟수 누적**(`{{MAX_IMPLEMENTER_ATTEMPTS}}` 한도 적용 — 기존 NEEDS_FIX 누적 규칙과 동일).
- **FAIL(플레이키니스/타이밍 의심)** → Debugger 브라우저 재현(§ 5.3)으로 로직 실패 vs 플레이키니스를 판별. 플레이키니스로 확인되면 **코드 수정 환각을 금지**하고 보고 후 Debugger Circuit Breaker(2회 → 사용자 에스컬레이션)를 따른다.

무한 루프는 기존 시도 한도 + Debugger Circuit Breaker가 차단한다 — VERIFY(E2E)는 독립 무한 재시도를 도입하지 않는다.

### 4.4 마찰 로그
이벤트 유형 테이블에 추가:
| 이벤트 | 기록 시점 | 심각도 |
|--------|----------|--------|
| `e2e-fail` | VERIFY(E2E)가 FAIL 반환 시 | high |

---

## 5. 에이전트 배선 (전부 런타임 조건부 → 7개 불변, 플레이스홀더 0)

세 managed 템플릿은 **항상 생성**되며, E2E 가이드는 "E2E 프레임워크 존재 시"라는 런타임 조건으로 보호된다 → 비-e2e 프로젝트에선 휴면(무해). §12.6 자동 감지로 전 하네스에 전파.

### 5.1 architect.md — E2E 슬롯 완성 (`:60`)
현재 미완성 슬롯 `E2E: {feature.steps 기반 시나리오, 해당 시}`를 완성:
- E2E 프레임워크가 있고 feature가 UI 상호작용이면, 각 step → E2E 시나리오 매핑을 명시한다.
- **@critical 후보**를 표시한다 — 어떤 흐름이 "절대 깨지면 안 되는 핵심"인지(증분 2b pre-push 게이트 대상이 될 후보). 보수적으로 최소만.

### 5.2 test-engineer.md — E2E 작성 심화 (`:19`, 결정 a)
기존 조건부 지시("E2E 프레임워크가 있으면 step당 E2E 케이스 1개")를 심화:
- `e2e/specs/{featureID}-{slug}.e2e.ts`로 작성(§ 3.3 네이밍), 테스트 제목에 `@feature:{featureID}`.
- 증분 1의 `e2e/fixtures/test.ts` base test 사용(per-test fresh context), `data-testid` 셀렉터 우선.
- Architect가 표시한 @critical 후보 중 핵심 흐름에만 `@critical` 부여 — **남용 금지**(§ 6).
- RED 종료 시 § 3.1 **E2E 판정 블록**을 Output에 포함(필수).

### 5.3 debugger.md — 브라우저 재현 모드
실패 테스트가 `.e2e.ts`면:
- Playwright 아티팩트(`playwright-report/`, trace.zip, 스크린샷)를 분석한다.
- 필요 시 `--headed`/trace 뷰어로 재현한다.
- **로직 실패 vs 플레이키니스(타이밍/네트워크/렌더 지연)를 명시적으로 판별**한다. 플레이키니스면 sleep 남발·불필요 비동기 지연 같은 **코드 환각 수정을 금지**하고, 근본 원인(셀렉터 대기·고정 시드·route-block 부재 등)을 RCA에 기록한 뒤 Circuit Breaker를 따른다. (gemini 환각 루프 우려 수용)

---

## 6. @critical 태그 (coding-standards.md)

`@critical` 정의를 검증 레벨 섹션 인근에 추가:
> **@critical**: 절대 깨지면 안 되는 핵심 사용자 흐름의 E2E 스펙에 부여하는 태그. **증분 2b pre-push 게이트 대상**(2a에서는 정의·작성 규율만 도입). Playwright `--grep @critical`로 필터. **남용 금지** — pre-push 속도·신뢰를 보존하기 위해 진짜 핵심 흐름에만 부여한다.

**거버넌스(자문 쟁점 — 내 판정)**: gemini는 "0건 강제 FAIL + 상한 N 하드코딩"을 권고했으나 **거부**한다 — 0건은 신규 프로젝트에 정당(핵심 흐름이 아직 없을 수 있음), 상한 하드코딩은 범용 스캐폴드 철학(프리셋 없어도 동작)에 어긋나는 과잉 규정. 대신:
- coding-standards에 "남용 금지" 규율 명시.
- Reviewer가 @critical 과다 부여를 감지하면 기존 **자동 검사 승격 대기 큐**(docs/TECH_DEBT.md)에 기록 — 사람/에이전트 규율을 기존 메커니즘으로 보강.
- (증분 2b의 pre-push 훅이 @critical 수가 비정상적으로 많으면 **경고**할 수 있으나 FAIL시키지 않는다 — 2b 범위.)

---

## 7. 정합성 계약 (구현 시 동시 갱신)

| 항목 | 2a 영향 |
|------|---------|
| **신규 플레이스홀더** | **0개** (29 불변). 모든 변경은 에이전트/룰 템플릿 텍스트 + Output Format + TDD STATE 런타임 블록 + 네이밍 규칙. `{{...}}` 없음. |
| **신규 파일** | **0개**. 기존 managed 템플릿(architect/test-engineer/debugger.md, session-routine.md, coding-standards.md)만 편집. |
| **manifest.files** | 변경 없음(신규 파일 0). 편집된 managed 템플릿은 §12.6 자동 감지(expectedHash vs templateHash 4-상태)로 전파. |
| **프로필 스키마** | 변경 없음 — `e2e.enabled`(1.11.0)를 게이트로 재사용. SKILL.md/harness-scaffold 양쪽 동일 유지. |
| **마이그레이션** | **불필요**. 선례: harness-scaffold/SKILL.md(M-1.0.0-to-1.1.0 주석) — "managed 템플릿 변경분은 §12.6 자동 감지로 전파되므로 마이그레이션에 포함하지 않는다." 5개 편집 파일 전부 managed. |
| **harness-check** | 변경 없음(2a). pre-push 활성 검사(⑨)는 2b. |
| **Phase 4 카탈로그** | 변경 없음(2a). 기존 1.11.0 E2E 줄 유지. @critical pre-push 게이트 광고는 2b(순수 투영 규칙 — pre-push 산출물이 아직 없으므로 광고 금지). |
| **버전** | MINOR → **1.12.0**. 동시 갱신: project-context.md · CHANGELOG.md · 프로필/매니페스트 version 필드 · git tag. |

---

## 8. 증분 2a 범위 밖 → 증분 2b (1.13.0, 보류)

pre-push 인프라는 실패 도메인이 달라 **2a 안정화 후 독립 릴리스**. 적대적 자문이 짚은 2b 난제(구현 시 별도 설계·검증):

| 2b 항목 | 자문 지적 | 해소 방향(2b에서 확정) |
|---------|----------|----------------------|
| `.githooks/pre-push`(신규 managed 파일) | codex: 결정적 매니페스트 등록 필수, M-1.11.0-to-1.12.0 → **2b 마이그레이션**으로 e2e.enabled일 때만 신규 파일 추가, 기존 훅은 4-상태 conflict | manifest managed 등록 + 조건부 마이그레이션 |
| 설치 메커니즘 (core.hooksPath) | codex/gemini: 기존 Husky/hooksPath와 **공존 불가**("충돌 시 경고"와 "강제"는 양립 불가) | **적응형 마커 주입**(eslintAssist 마커 관용구로 기존 훅에 @critical 체크 삽입), 활성 여부 정직 보고 |
| PM/설치 판정 | codex: `npm` 고정은 pnpm/yarn에서 깨짐, package.json 존재 ≠ 실행 가능 | `node_modules/.bin/playwright` 직접 호출(PM 비종속 + 실제 설치 판정) |
| @critical 탐지 | codex: 소스 `grep`은 주석/문자열 오탐, Playwright `--grep`과 의미 다름 | `playwright test --list --grep @critical`로 실제 매칭 수 판정(0-exit 동작은 픽스처 검증) |
| monorepo | codex: core.hooksPath는 repo-root 기준 → 하위 패키지에서 무력화 | repo-root 계산(`git rev-parse --show-toplevel`), **monorepo 하위 패키지는 명시적 한계로 보류**(침묵 누락 금지) |
| eslint e2e override | codex: 기존 eslint-assist 마커와 충돌 → 업그레이드 시 누락 | **별도 마커** `harness-setup:e2e-eslint:start/end` |
| 멱등성 | codex: core.hooksPath는 manifest 밖 외부 상태 | harness-check ⑨가 활성/비활성 명시 검사·보고 |
| 보안 고지 | codex: git hook은 push 시 임의 코드 실행 | Phase 4에 git hook/core.hooksPath 동작 고지 |
| "표준 하네스 가동" | codex: harness-check 통과 ≠ pre-push 활성/통과 | ⑨를 경고 전용으로 두고 판정과 분리 명시 |

증분 3(MCP 연계) · 증분 4(프리셋/문서/크로스브라우저)는 기존 § 11(증분 1 설계) 유지.

---

## 9. 수정 파일 (증분 2a)

**수정** (전부 managed 템플릿 + 트래킹):
- `templates/agents/architect.md` (E2E 슬롯 완성, § 5.1)
- `templates/agents/test-engineer.md` (E2E 작성 심화 + E2E 판정 Output, § 5.2 / § 3.1)
- `templates/agents/debugger.md` (브라우저 재현 모드, § 5.3)
- `templates/rules/session-routine.md` (VERIFY Phase 4.7 + Agent Dispatch 행 + TDD STATE 필드 + 마찰 이벤트, § 4 / § 3.4)
- `templates/rules/coding-standards.md` (@critical 정의 + 거버넌스, § 6)
- `references/harness-checklist.md` (§4.2 — L4 E2E가 TDD VERIFY에 배선됨 명시)
- `references/versioning-policy.md` (1.12.0 카운트 — 플레이스홀더 29 불변 확인)

**신규**: 없음.

**트래킹**: `.tracking/HANDOFF.md`, `.tracking/CHANGELOG.md`, `.tracking/TODO.md`(TODO-95 → 95a/95b 재분할), `references/project-context.md`.

**정합성 동시 갱신**: SKILL.md / harness-scaffold/SKILL.md의 프로필 스키마는 **변경 없음**(e2e 블록 1.11.0 유지) — 단, harness-scaffold §5.10(agents 생성)·§5.11(rules 생성) 본문이 편집된 템플릿 내용을 정확히 반영하는지 릴리스 전 대조.
