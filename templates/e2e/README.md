<!-- 하네스 생성 — E2E 작성 가이드 (harness-setup E2E 스캐폴드 모듈, managed). -->
<!-- 이 파일은 사람 개발자용 온보딩 문서다. 에이전트/TDD 규칙의 정본은 아래에서 참조하는 -->
<!-- .claude/rules/ · agents/ 파일이며, 이 문서는 그 규칙을 사람 관점에서 안내만 한다. -->

# E2E 테스트 작성 가이드 (`e2e/`)

이 디렉토리는 **브라우저 자동화(Playwright)** 기반 E2E 테스트다. jsdom 유닛 테스트(L2)가 못 잡는
실제 브라우저 동작 — 상호작용 회귀, 레이아웃/시각 회귀, 멀티스텝 사용자 흐름 — 을 검증한다.

> 이 모듈은 셋업에서 E2E 계층을 옵트인한 경우에만 존재한다. 명령은 프로젝트 패키지매니저에
> 맞춰 읽는다(`npm`/`yarn`/`pnpm`). 아래 예시는 `npm` 기준이다.

---

## 1. 무엇을 / 언제

- **실행**: `npm run test:e2e` — 실제 브라우저로 `e2e/specs/**/*.e2e.ts`를 돌린다.
- **`validate`와 분리**: 빠른 검증 루프(`npm run validate` = typecheck·lint·아키텍처·유닛)에는
  E2E가 **포함되지 않는다**(브라우저·dev 서버 기동 비용). E2E는 별도로 돌린다.
- **TDD 사이클 안의 위치**: feature 작업 중 RED 단계(Test Engineer)가 E2E 스펙을 작성하고,
  세션 루틴의 **VERIFY(E2E) (Phase 4.7)**가 해당 feature 스펙만 선택 실행한다.
  검증 레벨(L1 정적 / L2 유닛 / L3 통합 / L4 E2E)의 정의와 경계는 `.claude/rules/coding-standards.md`
  "검증 레벨"을 본다(여기서 중복하지 않는다).

**언제 E2E를 쓰는가** — feature가 ① **UI 상호작용**(클릭/입력/드래그/편집모드 등) **또는**
② **시각/레이아웃 회귀 위험**을 가질 때. 작성 규칙의 정본은 `agents/test-engineer.md`
"E2E 작성 규칙"이다. (②는 §5 참조.)

---

## 2. `e2e/` 레이아웃

```
e2e/
├── README.md            ← 이 문서
├── tsconfig.json        ← e2e 전용 컴파일 경계 (root tsconfig를 extends, root는 수정 안 함)
├── specs/
│   └── {featureID}-{slug}.e2e.ts   ← 회귀 스펙 (testMatch: **/*.e2e.ts)
└── fixtures/
    ├── test.ts          ← per-test base fixture (fresh context)
    └── seed.ts          ← 앱별 시드 헬퍼
```

- 스펙 파일명은 `{featureID}-{slug}.e2e.ts` 컨벤션을 따른다(예: `F12-task-reorder.e2e.ts`).
  `feature_list.json`의 feature와 연결된다.
- 네이밍이 `*.e2e.ts`인 이유: Vitest 기본 글롭(`**/*.{test,spec}.ts`)이 이 파일을 수집하지 **않아서**
  유닛 러너와 충돌하지 않는다. 따라서 `vitest.config`를 건드릴 필요가 없다.
- 설정은 루트 `playwright.config.ts`에 있다(`testDir: 'e2e/specs'`, `testMatch: '**/*.e2e.ts'`).

---

## 3. fixtures와 seed

- **`fixtures/test.ts`**: Playwright의 `test`를 확장한 base fixture. 각 테스트는 **fresh context**로
  시작한다(Playwright 기본). 스펙에서는 `import { test, expect } from '../fixtures/test'`로 쓴다.
- **`fixtures/seed.ts`**: 앱 상태를 미리 주입하는 헬퍼. `page.addInitScript(seed, payload)`로
  **앱 부팅 전** 브라우저 컨텍스트에서 실행된다. 가장 견고한 방법은 앱의 영속 저장소(localStorage 등)에
  직렬화 봉투를 직접 주입하는 것이다 — 직렬화 형태(DTO 배열 + version 등)와 키 이름을 앱의 persist
  설정과 **정확히 일치**시켜야 한다. 구체적 예시는 `e2e/fixtures/seed.ts`의 상단 주석에 있다.
- **앱 부팅 셋업**(필수 환경변수, 외부 인증 route-block, 시간 의존 UI의 clock 훅 등)은
  앱마다 다르므로 하네스가 일반화하지 않는다 — `playwright.config.ts` 하단의 "프로젝트별 셋업 가이드"
  주석을 보고 채운다(여기서 중복하지 않는다).

---

## 4. 셀렉터와 태그

- **셀렉터**: `data-testid`를 **우선** 사용한다(텍스트/CSS 셀렉터는 깨지기 쉽다).
- **`@feature:{featureID}` 태그**: 테스트 제목에 넣으면 VERIFY(E2E)가 `--grep @feature:{featureID}`로
  **그 feature 스펙만** 선택 실행한다. RED 단계에서 권장한다.
- **`@critical` 태그**: 절대 깨지면 안 되는 핵심 흐름(로그인·결제·데이터 손실 위험)에만 부여한다.
  **남용 금지** — 정의·정책의 정본은 `.claude/rules/coding-standards.md` "E2E @critical 태그"다.
  (이 태그가 pre-push 게이트에서 어떻게 쓰이는지는 §8 참조.)

---

## 5. 시각/레이아웃 회귀 트리거 (중요)

상호작용이 전혀 없어도, **렌더 결과의 기하(geometry)**에 의존하는 동작은 E2E 대상이다.
스크롤·오버플로·정렬·텍스트 넘침·반응형 레이아웃·고정 뷰포트 공간 분배 등이 여기 해당한다.

- **왜**: jsdom(L2 유닛)은 레이아웃 엔진이 없어 클래스/속성 존재만 확인할 뿐 실제 오버플로·정렬·스크롤을
  **검증하지 못한다**(정본: `.claude/rules/coding-standards.md` "jsdom 한계").
- **어떻게**: 셀렉터로 **측정 가능한 단언**을 쓴다 — 예: `boundingBox()`로 위치/크기,
  `scrollHeight`/`clientHeight` 비교로 스크롤 발생 여부, 요소 가시성.
- **육안 확인은 가드가 아니다**: 브라우저로 한 번 눈으로 본 것은 회귀를 막지 못한다.
  반드시 `.e2e.ts`로 **코드화**한다(세션 루틴의 완료 게이트 — `.claude/rules/session-routine.md`).

---

## 6. 실행

```bash
# 최초 1회 — 브라우저 바이너리 설치 (스캐폴드는 설치를 실행하지 않는다)
npm i
npx playwright install

# 전체 E2E
npm run test:e2e

# 특정 feature 스펙만
npm run test:e2e -- --grep @feature:F12

# 핵심 흐름만
npm run test:e2e -- --grep @critical
```

> `@playwright/test`는 `package.json`에 devDependency로 추가돼 있지만 **설치는 자동 실행되지 않았다**.
> 위 `npm i && npx playwright install`을 한 번 실행해야 브라우저가 준비된다.

---

## 7. (조건부) 브라우저 MCP 진단

이 하네스에 **브라우저 MCP 진단**(`e2e.mcp`)이 와이어돼 있다면, 재현 스펙이 아직 없는 UI 증상을
debugger 에이전트가 라이브 브라우저로 탐색·진단할 수 있다. known `.e2e.ts` 실패는 항상 러너가 정본이고,
MCP는 "아직 스펙이 없는" 탐색용이다. 등록·사용법은 `agents/debugger.md`의 MCP 진단 절을 본다.
(MCP가 와이어되지 않은 하네스라면 이 절은 무시한다.)

---

## 8. (조건부) pre-push 게이트

이 하네스에 **pre-push 게이트**(`e2e.prePush`)가 활성화돼 있다면, `git push` 시
`validate` 통과 후 `@critical` 태그 E2E가 **강제 실행**된다 — per-feature VERIFY(Phase 4.7)와 분리된
cross-feature 마지막 방어선이다. 그래서 `@critical`은 진짜 핵심 흐름에만 붙인다(§4·coding-standards).
활성화 방법(`git config core.hooksPath`)과 보안 고지는 셋업 보고/`.githooks/pre-push`를 본다.
(pre-push가 없는 하네스라면 이 절은 무시한다.)

---

> 이 문서는 사람 온보딩용 안내다. 규칙의 정본은 `.claude/rules/coding-standards.md`·
> `.claude/rules/session-routine.md`·`agents/test-engineer.md`·`agents/debugger.md`이며,
> 충돌 시 그쪽이 우선한다.
