# 핸드오프 — 이슈 #12 증분 4 (TODO-97): E2E 모듈 마감 (프리셋 + 문서 + U1 재감지 + §12.6.1 정렬)

> 작성: 2026-06-16 (Session 41 직후, 현재 버전 **1.16.0**)
> 대상: 새 세션이 이 문서 + `.tracking/HANDOFF.md` + `references/project-context.md`만 읽고 증분 4를 실행할 수 있도록 작성.
> 목표 버전: **1.17.0** (MINOR — 후방호환, 마이그레이션 불필요 예상). 4개 항목을 한 릴리스로 묶거나(권장) 분할 가능(D4).
> 스코핑 근거: 4개 영역 병렬 스카우트(general-purpose) 결과 종합. 모든 file:line은 스카우트가 검증.

---

## 0. 한눈에 — 증분 4의 4개 작업 항목

| # | 항목 | 핵심 결정 | 규모 | 의존 |
|---|------|----------|------|------|
| A | §12.6.1 e2e managed 매핑 정렬 | 없음(기계적) | 최소 | 무 — **먼저 처리 권장** |
| B | 프리셋 e2e 기본값 | **D1**: auto-enable vs pre-seed | 소 | 무 |
| C | U1 재감지 (base `e2e.enabled`) | **D3**: cascade 여부 | 소 | B의 §4.2 옵트인 로직 참조 |
| D | 사용자 E2E 작성 가이드 문서 | **D2**: 위치·카테고리 | 중(최대) | 무 |

**착수 전 사용자 확정 필요한 결정(아래 §6)**: D1(프리셋 기본값 의미), D2(가이드 위치), D3(U1 cascade), D4(단일 릴리스 vs 분할). D1·D2·D3는 "의견 개입" 성격이라 새 세션은 구현 전 사용자에게 확인할 것.

**불변 계약(전 항목 공통)**:
- 플레이스홀더 **31개 불변** — 모든 항목이 신규 플레이스홀더 0으로 설계 가능(아래 각 항목에서 `{{E2E_COMMAND}}` 등 기존 것 재사용).
- 두 SKILL.md의 `e2e` 프로필 스키마 블록 **byte-identical** 유지(CLAUDE.md 계약). `SKILL.md` 프로필 스키마 ↔ `harness-scaffold/SKILL.md` 입력 스키마.
- 기존 소스 비수정 원칙·옵트인·생략 기본 유지.

---

## A. §12.6.1 e2e managed 매핑 정렬 — **가장 작고 의존 없음, 먼저**

증분 2b가 증분 4로 명시 이월한 항목. `§12.6` 자동 감지는 모든 managed 파일이 `§12.6.1` 파일-템플릿 매핑 테이블에 있어야 동작하는데, e2e config 2개가 누락돼 있다.

**위치**: `§12.6.1`은 **`SKILL.md:1128-1148`**에 있다 (`harness-scaffold/SKILL.md:1074`는 참조만). ⚠️ harness-scaffold가 아님.

**현재 테이블(SKILL.md:1132-1146)**: agents/ 7개 + .claude/rules/ 3개 + init.sh + structural-test + doc-freshness + harness-check + `.githooks/pre-push`(1146, **이미 매핑됨 — 1.14.0이 추가**).

**누락 → 추가할 2행** (SKILL.md:1146 근처):
| 배포 파일 | 소스 템플릿 |
|---|---|
| `playwright.config.ts` | `templates/playwright.config.ts` |
| `e2e/tsconfig.json` | `templates/e2e/tsconfig.json` |

두 소스 템플릿 존재 확인됨. custom e2e 3개(fixtures/test.ts·seed.ts·specs/smoke.e2e.ts)는 **제외 유지**(user-owned).

**결정론 검증(완료)**: 두 템플릿 모두 expectedHash 안전 — `playwright.config.ts`는 `{{DEV_SERVER_COMMAND}}`/`{{DEV_SERVER_PORT}}`만(둘 다 `profile.devServer`에서, 저장 목록에 포함 → 재렌더 동일), `process.env.CI`/`Date`는 리터럴 소스 텍스트. `e2e/tsconfig.json`은 플레이스홀더 0(순수 정적 JSON).

**조건부 표기 불필요**: `§12.6`는 `manifest.files[]`의 `category: managed` 항목만 순회하고, manifest는 실제 생성된 파일만 기록(harness-scaffold/SKILL.md:912) → 비-e2e 하네스엔 해당 행이 참조조차 안 됨. `.githooks/pre-push`(e2e.prePush 조건부)가 이미 plain 행(1146)인 선례 그대로 plain 2행 추가.

**필수 후속**: `SKILL.md:1148`의 "e2e 두 파일 매핑은 증분 4로 이월" 주석을 **갱신/삭제**(행 추가하면서 주석을 남기면 자기모순).

**기존 e2e 하네스 영향**: 추가 후 다음 업그레이드에서 그들의 playwright.config.ts/tsconfig가 비로소 자동 감지 대상이 됨 — 의도된 동작. 별도 마이그레이션 엔트리 불필요(자동 감지 메커니즘 자체).

---

## B. 프리셋 e2e 기본값

**현재 상태**: 어떤 프리셋도 `e2e` **프로필** 필드를 갖지 않는다. 프리셋의 `testFramework.e2e`는 서술 문자열일 뿐(예 react-vite.json:65-68 `"e2e":"playwright"`, express-api.json:68-71 `"e2e":"supertest..."`) — 프로필 `e2e` 객체(`{enabled,framework,playwrightVersion,prePush,mcp}`)와 무관. 현재 `e2e`는 `프리셋 비대상`으로 명시(SKILL.md:666 필드 규칙 테이블, harness-scaffold/SKILL.md:183).

**현재 옵트인 결정 경로**:
- 트리거: `SKILL.md:180` (Step 1.4) — 프론트엔드 신호(testFramework.e2e==playwright **또는** stack에 UI 프레임워크 react/react-dom/vue/svelte/solid-js/@angular/core)면 §4.2 질문 트리거. 백엔드 전용(express) 제외.
- Q&A+기록: `SKILL.md:354-356` (§4.2) — "동의하면 프로필에 e2e 필드 기록 … **거부/무응답이면 필드 생략**(E2E 모듈 미생성)". 즉 **순수 옵트인, 기본 OFF**. version은 "현재 stable"로 자동 채움(질문 안 함).

**대상 프리셋**: react-next·react-router-fsd·**react-vite**(TODO-97 명시) — 3개 프론트엔드. **express-api는 제외**(백엔드, SKILL.md:180에서 트리거 자체 안 됨).

### ⚠️ D1 — 프리셋 기본값의 "의미" (사용자 확정 필요)

두 선례가 충돌하고 spec 문구("e2e 기본값 반영")가 모호:

- **Option A — auto-enable**: 프리셋이 `e2e.enabled:true`를 묻지 않고 프로필에 주입(docFreshnessDays/layer 규칙처럼 SKILL.md:433 "프리셋 값을 기본"). → 무마찰이나 **놀람**: `@playwright/test` devDep + playwright.config.ts + e2e/를 명시적 "예" 없이 생성. 1.11.0 e2e 모듈의 옵트인 설계 의도·파일 보호 원칙·"거부/무응답=생략" 계약과 충돌. autoCommit/eslintAssist/integrations가 **전부 의도적으로 프리셋 비대상**인 이유(프리셋이 파일 변형 동작을 조용히 켜지 못하게)와도 충돌.
- **Option B — pre-seed(권장)**: §4.2 질문은 여전히 뜨되 **권장 기본 답이 "예"로** 뒤집힘("이 스택은 보통 E2E를 원함"). 사용자 확인은 유지, 거부 시 생략. eslintAssist/autoCommit이 감지돼도 옵트인을 유지하는 방식과 정합.

**권장: Option B** — 계약 보존. 단 행동 변화가 작음(기본 답 nudge). 새 세션은 D1을 사용자에게 확인 후 진행.

**프리셋 값 shape**: 최소 `"e2e": {"enabled": true}`(B면 "권장 기본"으로 해석). **`playwrightVersion`은 프리셋에 하드핀 금지**(스킬보다 빨리 stale) — 기존 §4.2 "현재 stable" 자동 채움 유지. `prePush`/`mcp` 기본값 **시드 안 함**(독립 2차 옵트인, 각자 git/MCP 전제).

**편집 대상**:
- `presets/react-vite.json`·`react-next.json`·`react-router-fsd.json`에 `e2e` 블록 추가. **express-api.json 비변경**.
- `SKILL.md` §6 프리셋 스키마(≈725-782)에 선택 `e2e` 필드 문서화.
- `SKILL.md` §9 커스텀 프리셋 작성 가이드(≈851-869)에 새 선택 필드 명시(CLAUDE.md 동기 규칙).
- `SKILL.md:666` 필드 규칙 + §4.2(354-356): "프리셋 비대상" 단언이 **거짓이 됨 → 양쪽 SKILL.md 재서술**(B면 "프리셋이 권장 기본 제공, 여전히 옵트인 확인"). harness-scaffold/SKILL.md:183 미러 동시 수정(계약).
- `SKILL.md:433` 머지 우선순위가 새 프리셋 e2e 기본을 올바로 지배하는지 확인.

**Gotcha**: 새 필드 선택적이라 express-api(e2e 없음) 호환 유지(CLAUDE.md "모든 기존 프리셋 호환 확인"). 프리셋 필드는 **플레이스홀더 아님 → 31 불변**(harness-scaffold/SKILL.md:183, SKILL.md:666 "새 플레이스홀더 아님"). 골든 픽스처 영향 없음(프리셋 파싱은 픽스처 범위 밖), 단 §4.2/scaffold 게이팅 로직 바꾸면 `bash test/run-fixtures.sh`.

---

## C. U1 재감지 (base `e2e.enabled`)

**현재 상태**: base `e2e.enabled`에 대한 U1 재감지 **부재**(증분 1이 명시 이월, SKILL.md:1148). 선례 2개 존재:
- **pre-push 재감지** `harness-scaffold/SKILL.md:1743` (1.14.0+): "기존 `e2e.enabled` 하네스에 `e2e.prePush`가 없고 git 저장소면 … 옵트인 제안(생략 기본 — 거절/무응답 시 산출물 0건). 수락 시 §5.18 + manifest 등록. 활성화는 Phase U5 수동 안내."
- **MCP 재감지** `harness-scaffold/SKILL.md:1744` (1.15.0+): "기존 프론트엔드 하네스에 `e2e.mcp`가 없으면 … 제안 … 수락 시 debugger.md `{{MCP_DEBUG_PROTOCOL}}` 재치환."

두 불릿은 §10.3 "마이그레이션 불필요" 프로즈 블록(1737-1741) 직후, `### 10.4 엣지 케이스`(1746) 직전 = **삽입 존(1742·1745 공백)**.

**추가할 불릿**(1743 pre-push **앞**에 prepend → 읽기 순서 base→pre-push→MCP, 신규셋업 질문 순서 SKILL.md:354/357/360과 일치):
> **E2E 재감지** (1.17.0+ U1): 프론트엔드로 감지됐는데 프로필에 `e2e.enabled`(또는 `e2e` 블록) 부재면, 업그레이드 U1 재감지에서 브라우저 E2E 계층(Playwright) 옵트인을 **제안**한다(생략 기본 — 거절/무응답 시 산출물 0건). 수락 시 §5.17 생성(playwright.config.ts·e2e/ — managed+custom 신규 파일) + manifest 등록(profile.e2e + 신규 templateHash). `@playwright/test` 설치는 §5.5 add-only 머지 후 Phase U5 수동 안내(스킬 미설치).

프론트엔드 신호는 **SKILL.md:180과 동일 재사용**(새 휴리스틱 금지 — MCP 재감지가 "기존 프론트엔드 하네스"로 이미 그렇게 함).

### ⚠️ D3 — cascade 여부 (사용자/구현 확정)

pre-push 재감지(1743)의 전제는 "**기존** `e2e.enabled` 하네스". 같은 업그레이드에서 base E2E를 막 수락한 경우 pre-push 제안이 **같은 U1 패스에서 이어질지**(cascade) vs 다음 업그레이드로 미룰지 결정 필요.
- **권장: cascade** — 신규셋업이 E2E 확인 직후 pre-push를 묻는 SKILL.md:357을 미러. 새 불릿에 "수락 시 이어서 pre-push 재감지(1743) 평가" 절을 명시하거나, 1743 전제를 "기존 또는 금번 수락한 e2e.enabled"로 완화.
- **MCP 재감지(1744)는 독립 유지** — `e2e.enabled` 무관(frontend+`e2e.mcp` 부재 키). base E2E 추가가 MCP 트리거를 바꾸면 안 됨.

**마이그레이션 불필요 프로즈**(1737-1741 블록에 `> **1.17.0**(이슈 #12 증분 4) …` 추가): ⚠️ **pre-push 프레이밍 사용**(수락 시 신규 파일 생성) — MCP의 "신규 파일 안 만든다" 프레이밍 복사 금지. 근거: "생략=off, 기존 하네스 산출물 0건; 신규 파일은 U1 재감지 옵트인 경로로만".

**정본 위치**: harness-scaffold §10.3에만(pre-push/MCP 선례가 SKILL.md U1 박스 968-1009에 중복 안 됨). 신규 프로필 필드·플레이스홀더 0.

---

## D. 사용자 E2E 작성 가이드 문서 — **최대 규모**

**대상 독자**: 타깃 프로젝트의 **사람 개발자**(에이전트 아님). test-engineer.md(19-41)·coding-standards.md(24-44)·playwright.config.ts:29-32 인라인 가이드가 이미 **에이전트/규칙 측** 내용을 소유 → 가이드는 이들을 **참조**하고 사람-온보딩 voice로만 재서술(중복 금지).

**현재 생성 e2e 파일(§5.17, e2e.enabled 시만)**: playwright.config.ts(managed)·e2e/tsconfig.json(managed)·fixtures/test.ts(custom)·fixtures/seed.ts(custom)·specs/smoke.e2e.ts(custom). +pre-push(managed,prePush시)·MCP(파일 0, debugger.md 치환).

### ⚠️ D2 — 위치·카테고리 (사용자 확정 권장)

| 옵션 | 전파 | 마이그레이션 | 평가 |
|------|------|------------|------|
| (a) 신규 생성 파일 `e2e/README.md` **managed** | §12.6 자동 감지 재렌더 | e2e.enabled 게이트면 **불필요**(1.11.0 선례) | **권장** — dev가 일하는 곳(e2e/), 최신 유지 |
| (a') 같은 파일 **custom** | 안 됨 | 변경마다 마이그레이션 | 정적 가이드엔 부적합 |
| (b) 기존 managed 문서에 섹션 | §12.6 자동 | 불필요 | 신규 파일 0이나 에이전트-규칙 문서에 사람 prose 혼입 + 비-e2e 하네스에도 출현 |
| (c) 스킬 repo 전용 참조 문서 | 안 됨 | 무 | 타깃 프로젝트 dev가 못 봄 — 요구 미충족 |

**권장: (a) `templates/e2e/README.md`, category=managed, `e2e.enabled` 엄격 게이트** → 1.11.0/1.14.0 "마이그레이션 없음" 속성 상속(기존 비-e2e 하네스 산출물 0).

**내용 개요**(사람-온보딩, 규칙은 참조만):
1. 무엇/언제 — `npm run test:e2e`(=`{{E2E_COMMAND}}`), validate와 분리, VERIFY(E2E) Phase 4.7 매핑. L1-L4는 coding-standards 참조 1줄.
2. `e2e/` 레이아웃 — specs/`{featureID}-{slug}.e2e.ts`(testMatch), fixtures/test.ts(fresh context), fixtures/seed.ts.
3. fixtures·seed — `page.addInitScript` 시드 주입, persist-envelope(seed.ts 주석). 앱 부팅(env·auth route-block·clock)은 playwright.config.ts:29-32 참조(중복 금지).
4. 셀렉터·태그 — data-testid 우선, `@feature:{ID}`(VERIFY 선택), `@critical`(pre-push 전용, coding-standards 참조).
5. **시각/레이아웃 회귀 트리거(1.16.0)** — geometry 의존(스크롤/오버플로/정렬/넘침/반응형/뷰포트 분배)이면 상호작용 없어도 E2E, jsdom 레이아웃 엔진 부재. 측정 단언(`boundingBox`, `scrollHeight/clientHeight`, 가시성). 육안 1회는 가드 아님 → `.e2e.ts` 코드화. (test-engineer.md:20 + coding-standards.md jsdom 한계의 사람-facing 재서술.)
6. 실행 — test:e2e, `--grep @feature/@critical`, 최초 `npm i && npx playwright install`(스캐폴드 미설치, harness-scaffold/SKILL.md:545).
7. (조건부 MCP) `e2e.mcp` 시 debugger §0.5 1줄 포인터.
8. (조건부 pre-push) `e2e.prePush` 시 @critical cross-feature 강제 1줄.

### D2 하위 결정
- 파일 경로: `e2e/README.md`(권장, in-place) vs `docs/E2E_GUIDE.md`.
- 카테고리: managed(권장) vs custom.
- 조건부 섹션(7·8): 정적 "if wired" 문구(권장 — §12.6 재렌더 결정론 보존) vs 프로필 게이트 렌더(분기 비용 + 결정론 주의).
- 플레이스홀더: `{{E2E_COMMAND}}`(기존, harness-scaffold/SKILL.md:754) **재사용 → 신규 0, 31 불변**. 일반 문구 `npm run test:e2e`도 가능.

**편집 대상**:
- 신규 `templates/e2e/README.md`.
- harness-scaffold/SKILL.md: §5.17 생성 테이블(1027-1033)에 행 추가, §5.17 규칙(1037-1040) 정적 prose·managed 명시, **§10.1 분류 테이블(1445-1450) 재번호**(신규 행 추가 → `.githooks/pre-push` #31→#32 이동, **이름 참조라 번호 하드참조 없음 확인**), 생성 순서 step 19(223), Phase 4 카탈로그(1321)는 기존 E2E 줄에 `e2e/README.md` 상세 포인터(신규 카탈로그 줄 불필요), 1737-1741에 1.17.0 무마이그레이션 노트.
- references/harness-checklist.md §4.2(118-123) 1줄, versioning-policy.md(224 뒤) 1.17.0 행.
- ⚠️ **`{{E2E_COMMAND}}` 인라인 시 §6.11 미치환 grep(harness-scaffold/SKILL.md:1154)에 `e2e/README.md` 추가** — 안 하면 잔여 `{{` 미검출. 일반 문구면 불필요.

**Gotcha**: e2e.enabled 게이트 엄수(무마이그레이션 load-bearing). 에이전트-규칙 내용 복제 금지(참조). 조건부 렌더는 profile의 순수 함수여야 §12.6 안전.

---

## 5. 권장 시퀀스 (1.17.0 단일 릴리스 가정)

1. **A(§12.6.1)** — 무결정, 잠재 버그 정렬. 먼저.
2. **B(프리셋)** — D1 확정 후.
3. **C(U1 재감지)** — D3 확정 후. B의 §4.2 옵트인 로직 참조.
4. **D(가이드 문서)** — D2 확정 후. 최대 규모, 마지막.
5. 버전/트래킹/검증 일괄: 두 SKILL.md version 1.17.0, versioning-policy·project-context·CHANGELOG·HANDOFF, TODO-97 완료.

**검증**: `bash test/run-fixtures.sh` + e2e/mcp/prepush 픽스처 / 두 SKILL.md `e2e` 스키마 IDENTICAL diff / 31 플레이스홀더 불변 / `git grep "증분 4"` 잔여 deferral 주석(SKILL.md:1148) 제거 확인 / (D 시) §6.11 grep 커버리지.

---

## 6. 착수 전 사용자 확정 결정 (요약)

- **D1** 프리셋 기본값 = auto-enable(A) vs **pre-seed 권장(B)**. ← 옵트인 계약·파일 보호 영향, 의견 개입.
- **D2** 가이드 위치 = **`e2e/README.md` managed 권장** vs docs/ vs custom vs 기존 문서 섹션.
- **D3** U1 base-E2E 수락 → 같은 업그레이드에서 pre-push 제안 **cascade 권장** vs 다음 업그레이드.
- **D4** 4항목 **단일 1.17.0 권장** vs 분할(예: A를 선행 PATCH).

→ 새 세션은 D1·D2·D3을 사용자에게 확인(AskUserQuestion)한 뒤 design doc(`docs/superpowers/specs/2026-06-16-e2e-incr4-design.md`) + plan으로 확정하고 구현. A는 결정 없이 바로 가능.

---

## 7. 핵심 file:line 앵커 (스카우트 검증)

- §12.6.1 매핑: `SKILL.md:1128-1148` (deferral 주석 1148), pre-push 기존 행 1146.
- 프리셋 옵트인: `SKILL.md:180`(트리거)·354-356(§4.2 Q&A)·433(머지)·666(필드규칙)·≈725-782(§6 스키마)·≈851-869(§9 가이드). 미러 harness-scaffold/SKILL.md:183.
- U1 재감지: harness-scaffold/SKILL.md **1743/1744**(선례), 1737-1741(무마이그레이션 프로즈), 1742·1745(삽입 존). 신규셋업 순서 SKILL.md:354/357/360.
- 가이드 문서: §5.17 테이블 harness-scaffold/SKILL.md:1027-1040, §10.1 카테고리 1445-1450, 무마이그레이션 선례 1737-1741, Phase 4 카탈로그 1312-1355, `{{E2E_COMMAND}}` 정의 754, §6.11 grep 1154, 설치 미실행 545. 에이전트-규칙 소유 test-engineer.md:19-41 / coding-standards.md:24-44 / playwright.config.ts:29-32.
- 플레이스홀더 카운트 prose: `SKILL.md:919`, `versioning-policy.md:14,37`.
