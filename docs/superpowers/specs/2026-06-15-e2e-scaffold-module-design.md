# 설계: E2E 스캐폴드 모듈 (이슈 #12 증분 1)

> 작성일: 2026-06-15
> 출처 이슈: #12 — 하네스에 브라우저 테스트/디버깅 계층 추가
> 범위: 이슈 #12의 **증분 1 / 4** (E2E 스캐폴드 모듈). 나머지 증분은 § 11 참조.
> 목표 버전: **1.11.0** (MINOR)

---

## 1. 배경 & 동기

하네스는 이미 **L4 E2E 슬롯을 예약해두고도 비워둔 상태**다. 탐색으로 확인된 기존 슬롯:

- `references/harness-checklist.md` §4.2 — "Level 4 E2E: 브라우저 자동화로 실제 시나리오 재현" + "feature_list의 steps가 E2E 테스트와 1:1로 매핑 가능한가"
- `references/harness-checklist.md` §5.3 — "검증 없는 완료 방지: E2E/실동작 확인이 종료 절차에 포함되는가"
- `templates/rules/coding-standards.md` — L4 "브라우저 자동화" 정의 + steps↔E2E 1:1 매핑 규칙
- `templates/agents/architect.md:60` — E2E 출력 슬롯 (미완성: `'E2E: {feature.steps 기반 시나리오, 해당 시}'`)
- `templates/agents/test-engineer.md:19` — 조건부 E2E 지시 ("E2E 프레임워크가 있으면 step당 E2E 케이스 1개")

**그러나 구현 경로가 없다.** 프론트엔드 상호작용 회귀(편집모드 재오픈, 드래그 오발동, StrictMode 이중 effect 등)는 jsdom 단위 테스트가 구조상 못 잡는 클래스이며, 현재는 사람이 수동으로 브라우저를 띄워 잡는다.

증분 1은 이 슬롯을 **실제로 동작하는 E2E 스캐폴드**로 채운다 — 즉 하네스가 프론트엔드 프로젝트에 Playwright 기반 E2E 셋업(설정·디렉토리·스크립트·의존성)을 생성하는 능력. TDD 사이클 배선·MCP·강제 훅은 이후 증분이다.

---

## 2. 핵심 설계 결정 (헤드라인)

E2E를 **1급 옵트인 스캐폴드 모듈**로 추가한다.

- `integrations.<name>`(연계 스킬)이 **아니다** — Playwright는 외부 스킬/CLI가 아니라 프로젝트별 dev 의존성 스캐폴드다.
- `extras`(단순 룰 텍스트 생성)도 **아니다** — 설정·디렉토리·스크립트·의존성을 함께 다루므로 더 크다.
- `eslintAssist`와 같은 위상이다: **감지 → 옵트인 질문 → 외과적 스캐폴드**.

두 불변식을 모두 보존한다:
1. **비침습**: 기존 소스 코드 비수정, 설정 파일은 옵트인 외과적 머지만 (`tsconfig`는 어떤 경우에도 비수정).
2. **결정적 매니페스트**: 매니페스트에 없는 파일 생성 금지 → 새 파일은 모두 `manifest.files`에 카테고리 등록.

---

## 3. 프로필 스키마 변경 (계약)

`SKILL.md`(출력)와 `harness-scaffold/SKILL.md`(입력) **양쪽**의 프로필 스키마에 새 최상위 블록을 추가한다. 두 파일의 스키마는 항상 동일해야 한다(계약).

```jsonc
"e2e": {                       // 옵트아웃 시 필드 자체를 생략 (= 비활성, eslintAssist 선례)
  "enabled": true,
  "framework": "playwright",   // 증분 1은 playwright 고정 (포워드 호환 마커)
  "playwrightVersion": "1.x.y" // 핀 버전 — 구현 시 현재 stable로 확정, 스킬 기본값 유지
}
```

**최소 계약 원칙(YAGNI)**: 증분 1은 단일 브라우저(chromium)·고정 경로(`e2e/specs`, `e2e/fixtures`)이므로 이들은 프로필 필드가 아니라 **템플릿 고정 컨벤션**으로 둔다. 설정 가능성이 실제로 필요해지면(예: 크로스브라우저 증분 4) 그때 프로필 필드로 승격한다 — 미사용 필드를 선제 도입하지 않는다.

**규칙**: 필드 부재 = 비활성(명시적 `false` 아님). 이는 `_protocol.md`의 "omit field is default" 및 `eslintAssist` 옵트인 규칙과 일관.

**버전 핀**: `playwrightVersion`의 구체 값은 구현 시 현재 stable `@playwright/test` 버전으로 확정하고, 스킬이 기본값으로 유지(향후 업데이트는 PATCH/MINOR로 관리).

---

## 4. 감지 & 옵트인 (SKILL.md 분석)

### 4.1 프론트엔드 신호로 게이트
다음 중 하나면 "프론트엔드 프로젝트"로 판정하고 E2E 옵트인을 제안한다:
- `testFramework.e2e === "playwright"` (react 프리셋 3종: react-next / react-router-fsd / react-vite)
- package.json에 UI 프레임워크 감지: `react` / `react-dom` / `vue` / `svelte` / `solid-js` / `@angular/core`

`express-api`(testFramework.e2e = supertest) 등 백엔드 프로젝트는 **스킵** — 질문하지 않고 산출물에 e2e 0건.

### 4.2 옵트인 질문
프론트엔드 감지 시에만 §4.2 질문 풀에 1개 추가:
> "브라우저 E2E 계층(Playwright)을 셋업할까요? jsdom이 못 잡는 상호작용 회귀를 자동화합니다."

- 예 → `e2e` 블록을 프로필에 기록.
- 아니오/생략 → `e2e` 필드 생략. (`eslintAssist`·integrations와 동일한 옵트인 흐름)

---

## 5. 생성 파일 & 카테고리 (harness-scaffold)

| 파일 | 카테고리 | 비고 |
|------|---------|------|
| `playwright.config.ts` | **managed** | 4-상태 diff, 템플릿 개선 추적 |
| `e2e/tsconfig.json` | **managed** | root tsconfig 확장, 자체 컴파일 경계 |
| `e2e/fixtures/seed.ts` | **custom** | 1회 생성, TODO 가이드 (사용자 소유) |
| `e2e/fixtures/test.ts` | **custom** | per-test fresh context base test |
| `e2e/specs/smoke.e2e.ts` | **custom** | 제너릭 스타터 스모크 |
| package.json `scripts.test:e2e` | (기존 §5.5 머지) | `"playwright test"` — **validate엔 미포함** |
| package.json `devDependencies."@playwright/test"` | (§5.5 머지 확장) | 핀 버전 add-only |
| eslint e2e 오버라이드 | (조건부) | `eslintAssist.enabled`일 때만 마커 블록 |

**카테고리 근거**: managed = 템플릿 개선을 4-상태 자동 감지로 전파(설정은 하네스가 진화). custom = 사용자가 채우고 소유(테스트/시드는 프로젝트별) → 업그레이드 시 미덮어쓰기.

### 5.1 신규 플레이스홀더
- `{{PLAYWRIGHT_VERSION}}` **1개만** 추가. (`specDir`/`browser`는 템플릿 고정 기본값, webServer는 기존 `{{DEV_SERVER_COMMAND}}`/`{{DEV_SERVER_PORT}}` 재사용)
- harness-scaffold §4 치환 규칙 테이블 + (해당 시) presets 스키마 가이드에 반영.

### 5.2 생성 순서
기존 20단계 중 **package.json scripts(18) 이후, .harness-manifest.json(20) 이전**에 신규 단계 삽입 (e2e.enabled일 때만 실행). 의존성: webServer가 devServer 정보를 쓰므로 devServer 확정 이후, manifest가 파일 목록을 쓰므로 그 이전.

### 5.3 package.json 머지 확장
현재 §5.5의 안전 머지(키 부재 시에만 추가, 기존 키 보존)를 확장:
- `scripts.test:e2e` 추가 (부재 시).
- `devDependencies."@playwright/test"` 추가 (부재 시, 핀 버전). **install은 실행하지 않음** — Phase 4에서 안내.
- 멱등: 키가 이미 있으면 스킵.

---

## 6. 3개 툴체인 펜스 (해소 완료)

| 펜스 | 해소 방식 | 비침습 영향 |
|------|----------|------------|
| **Vitest 글롭 충돌** | e2e 스펙을 `*.e2e.ts`로 명명 → Vitest 기본 글롭(`**/*.{test,spec}.ts`)이 미매칭, playwright.config가 `testMatch:'**/*.e2e.ts'`로 명시 매칭 | vitest.config **미수정** |
| **tsconfig 분리** | `e2e/tsconfig.json`(자체) 생성 + root tsconfig **절대 비수정**. root가 broad include면 harness-check가 **감지·경고만** | tsconfig **미수정** |
| **eslint 타깃** | `eslintAssist.enabled`인 경우 기존 마커 메커니즘으로 e2e 오버라이드 블록 추가, 아니면 Phase 4 안내로 위임 | 옵트인 마커 머지만 |

> Vitest 충돌은 이슈가 "가장 load-bearing"이라 짚었고, 이슈 설계는 `.spec.ts` + `exclude` 머지였다. 본 설계는 **네이밍 컨벤션으로 회피**하여 vitest.config 수정을 아예 제거한다 — 하네스의 비침습·멱등 불변식에 더 부합.

---

## 7. 템플릿 내용

### 7.1 `playwright.config.ts`
- `testDir: 'e2e/specs'`, `testMatch: '**/*.e2e.ts'`
- `webServer: { command: {{DEV_SERVER_COMMAND}}, port: {{DEV_SERVER_PORT}}, reuseExistingServer: !process.env.CI }`
- `use: { baseURL: 'http://localhost:{{DEV_SERVER_PORT}}' }`, per-test fresh context (Playwright 기본)
- `projects: [chromium]` (단일 브라우저)
- **주석 가이드** (강제 아님): 앱별 부팅 의존성 — 더미 env 주입, auth `**/auth/v1/**` route-block, 시간 고정(clock)은 날짜 테스트만.

### 7.2 `e2e/tsconfig.json`
- root tsconfig를 `extends`, e2e 디렉토리만 `include`. Playwright/Node 타입 포함.

### 7.3 `e2e/specs/smoke.e2e.ts` (스타터)
- baseURL 로드 + `<body>` 가시성 단언 (프레임워크 무관 제너릭).
- 주석: "이 스모크는 시작점. 앱 부팅 의존성(env/route-block)이 있으면 fixtures에서 처리."

### 7.4 `e2e/fixtures/seed.ts` / `test.ts`
- `test.ts`: Playwright `test`를 확장한 base test (per-test fresh context, 시드 훅 자리).
- `seed.ts`: 시드 헬퍼 **구조 + TODO 가이드**. HAJA식 localStorage persist 봉투(`{state:{...}, version}`)는 **주석 예시로만** 제시(강제·앱가정 없음).

---

## 8. harness-check & Phase 4 보고

### 8.1 harness-check.sh — 구조적 검사만
`e2e.enabled`일 때만 활성화되는 항목 추가:
- `playwright.config.ts` 존재
- `scripts.test:e2e` 존재
- `e2e/` 디렉토리 구조 존재
- root tsconfig broad-include 충돌 감지 시 **경고**(exit 0) — root tsconfig에 `include`가 없거나(전체 디렉토리 컴파일) `e2e`를 포함하는 패턴이면 텍스트 검사로 감지하고 "`e2e/`를 root tsconfig exclude에 추가 권장" 경고. tsconfig는 수정하지 않는다.

**스위트는 실행하지 않는다** → 1.9.0 "구조 보장, 의미 비보장" 원칙 일관. E2E 그린은 앱별 부팅에 의존하므로 의미 정확성은 판정 대상이 아니다.

### 8.2 Phase 4 능력 카탈로그 (1.10.0)
`이제 할 수 있는 일` 블록에 1줄 추가:
> `브라우저 E2E 회귀 작성 → npm run test:e2e (상세: e2e/, playwright.config.ts)`

**순수 투영 규칙 준수**: 이 줄은 `e2e.enabled` 신호 + 산출물(playwright.config/e2e/)에 게이트된다 — 미와이어 능력 광고 불가. 새 게이트 로직 없이 기존 신호 재사용.

---

## 9. 업그레이드 / 마이그레이션

- **강제 마이그레이션 없음** (옵트인 모듈). U1 재감지가 기존 **프론트엔드** 하네스에 e2e 옵트인을 제안한다 — superpowers/multi-model-consult의 "업그레이드 시 옵트인" 패턴과 동일.
- 이미 `e2e` 보유 하네스: managed 파일(`playwright.config.ts`·`e2e/tsconfig.json`)의 템플릿 변경을 §12.6 4-상태 자동 감지로 전파. custom 파일은 미덮어쓰기.
- manifest 스키마: 새 카테고리 파일 정의 추가(파일 목록 확장). Public API 무변경(옵트인·하위호환) → MINOR.

---

## 10. 정합성 계약 (구현 시 동시 갱신 필수)

CLAUDE.md 개발 규칙에 따른 동시 갱신 지점:
1. **프로필 스키마**: `SKILL.md` 출력 스키마 = `harness-scaffold/SKILL.md` 입력 스키마 (§3의 `e2e` 블록).
2. **플레이스홀더**: `{{PLAYWRIGHT_VERSION}}`를 harness-scaffold 치환 규칙 테이블에 추가.
3. **생성 파일 목록**: harness-scaffold §5 파일 목록 = 실제 `templates/` 구조 = manifest.files = harness-check 타깃 = doc-freshness 타깃.
4. **카탈로그 렌더링 규칙**: Phase 4 카탈로그의 e2e 줄은 산출물 게이트 신호(`e2e.enabled`)를 동일하게 가진다.
5. **버전**: `project-context.md`·`CHANGELOG.md`·프로필/매니페스트 version 필드·`git tag` 동시 1.11.0.

---

## 11. 증분 1 범위 밖 (이후 증분)

| 증분 | 내용 |
|------|------|
| 2 | TDD 사이클 배선(VERIFY 단계) + `@critical` 태그 + pre-push 강제 훅 + agents 배선(architect E2E 슬롯 완성, test-engineer E2E 작성, debugger 브라우저 재현 모드) |
| 3 | MCP Layer A: `.mcp.json` 공식 `@playwright/mcp` + debugger 브라우저 재현(에이전트 인-더-루프) |
| 4 | 프리셋 e2e 블록 + 크로스브라우저 + 문서/카탈로그/체크리스트 마감 + 백필 |

---

## 12. 수정/신규 파일 (증분 1)

**수정**:
- `SKILL.md` (감지 §1.x, 옵트인 §4.2, 프로필 출력 스키마)
- `harness-scaffold/SKILL.md` (입력 스키마, 생성 단계, 치환 규칙, manifest 카테고리, 생성 순서, Phase 4 카탈로그)
- `templates/harness-check.sh` (구조적 e2e 검사 항목)
- `references/harness-checklist.md` (§4.2 구현 경로 명시)
- `references/versioning-policy.md` (스키마 version)

**신규**:
- `templates/playwright.config.ts`
- `templates/e2e/tsconfig.json`
- `templates/e2e/fixtures/seed.ts`
- `templates/e2e/fixtures/test.ts`
- `templates/e2e/specs/smoke.e2e.ts`

**트래킹**: `.tracking/HANDOFF.md`, `.tracking/CHANGELOG.md`, `.tracking/TODO.md`, `references/project-context.md`
