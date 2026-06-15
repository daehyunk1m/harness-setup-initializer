# E2E 스캐폴드 모듈 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 하네스가 프론트엔드 프로젝트에 동작하는 Playwright 기반 E2E 셋업(설정·디렉토리·스크립트·의존성)을 옵트인으로 스캐폴드하는 능력을 추가한다 (이슈 #12 증분 1).

**Architecture:** E2E를 `eslintAssist`와 같은 위상의 **1급 옵트인 스캐폴드 모듈**로 추가한다. 프로필에 선택 필드 `e2e` 블록을 두고, 프론트엔드 감지 시에만 옵트인 질문을 던지며, 동의 시 `templates/e2e/*` + `playwright.config.ts`를 생성하고 package.json에 `test:e2e` 스크립트와 `@playwright/test` devDependency를 add-only 머지한다. Vitest 글롭 충돌은 `*.e2e.ts` 네이밍으로 회피하여 vitest.config를 일절 수정하지 않는다. 두 불변식(비침습 — tsconfig 절대 비수정 / 결정적 매니페스트 — 모든 파일 카테고리 등록)을 보존한다.

**Tech Stack:** Markdown 스펙(SKILL.md ×2), TypeScript 템플릿(playwright.config.ts, e2e/*), Bash(harness-check.sh, 골든 픽스처 테스트), JSON(프로필/매니페스트 스키마). 테스트는 `bash test/*.sh` + `node -e`로 실행(리포 루트에 package.json 없음).

**설계 정본:** `docs/superpowers/specs/2026-06-15-e2e-scaffold-module-design.md`

---

## 파일 구조 (생성/수정 대상)

**신규 템플릿 (5):**
- `templates/playwright.config.ts` — Playwright 설정 (managed). `{{DEV_SERVER_COMMAND}}`/`{{DEV_SERVER_PORT}}` 재사용.
- `templates/e2e/tsconfig.json` — e2e 전용 컴파일 경계 (managed). 플레이스홀더 없음.
- `templates/e2e/fixtures/test.ts` — per-test base fixture (custom).
- `templates/e2e/fixtures/seed.ts` — 시드 헬퍼 가이드 (custom).
- `templates/e2e/specs/smoke.e2e.ts` — 스타터 스모크 (custom).

**신규 테스트 (1):**
- `test/e2e-fixtures.sh` — 템플릿 렌더 + JSON 유효성 + Vitest 비충돌 회귀 앵커.

**수정 스펙 (6):**
- `harness-scaffold/SKILL.md` — 입력 스키마, 생성 순서/단계(§5.17 신규), §5.5 package.json 머지 확장, §5.13 manifest profile 부분집합, §6 검증, §7 카탈로그, §10.1 카테고리 테이블, version.
- `SKILL.md` — 출력 스키마, Step 1.4 감지, §4.2 옵트인 질문, §7 절대 규칙, version.
- `templates/harness-check.sh` — ⑧ E2E 구조 검사 (경고 전용, 자기 게이트).
- `references/harness-checklist.md` — §4.2에 E2E 구현 경로 명시.
- `references/versioning-policy.md` — 버전 히스토리 근거(카운트 불변 확인).
- `references/project-context.md` — §4 버전 히스토리 1.11.0 항목.

**트래킹 (3):** `.tracking/HANDOFF.md`, `.tracking/CHANGELOG.md`, `.tracking/TODO.md`

**버전:** 1.10.0 → **1.11.0** (MINOR — 옵트인 선택 필드 + 새 파일, 하위 호환).

---

## Task 1: E2E 템플릿 5종 + 골든 픽스처 테스트

**Files:**
- Test: `test/e2e-fixtures.sh`
- Create: `templates/playwright.config.ts`
- Create: `templates/e2e/tsconfig.json`
- Create: `templates/e2e/fixtures/test.ts`
- Create: `templates/e2e/fixtures/seed.ts`
- Create: `templates/e2e/specs/smoke.e2e.ts`

- [ ] **Step 1: 실패하는 골든 픽스처 테스트 작성**

`test/e2e-fixtures.sh` 생성:

```bash
#!/bin/bash
# E2E 스캐폴드 모듈 골든 픽스처 — 스킬 자체 검증 (생성 프로젝트와 무관, footprint 0)
#
# 목적:
#   1. templates/playwright.config.ts·e2e/* 가 플레이스홀더 치환 후 잔여 {{}} 없이 렌더되는가
#   2. e2e/tsconfig.json 이 유효한 JSON 인가
#   3. 네이밍 컨벤션 *.e2e.ts 가 Vitest 기본 글롭에 안 잡히고 Playwright testMatch엔 잡히는가
#      (이슈 #12의 "가장 load-bearing" 결정 — vitest.config 미수정 회귀 앵커)
#
# 요구: node. 사용법: bash test/e2e-fixtures.sh

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$ROOT/templates"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

echo "═══ E2E 스캐폴드 모듈 픽스처 ═══"

# ── 1. 템플릿 렌더 (플레이스홀더 치환 — playwright.config.ts만 치환 대상) ──
sed -e "s#{{DEV_SERVER_COMMAND}}#npm run dev#g" \
    -e "s#{{DEV_SERVER_PORT}}#3000#g" \
    "$TEMPLATES/playwright.config.ts" > "$TMP/playwright.config.ts"
cp "$TEMPLATES/e2e/tsconfig.json"        "$TMP/e2e-tsconfig.json"
cp "$TEMPLATES/e2e/fixtures/test.ts"     "$TMP/test.ts"
cp "$TEMPLATES/e2e/fixtures/seed.ts"     "$TMP/seed.ts"
cp "$TEMPLATES/e2e/specs/smoke.e2e.ts"   "$TMP/smoke.e2e.ts"

if grep -rl '{{.*}}' "$TMP" >/dev/null 2>&1; then
  echo "❌ 렌더 후 미치환 플레이스홀더 잔존:"; grep -rn '{{.*}}' "$TMP"
  FAILS=$((FAILS + 1))
else
  echo "✅ 플레이스홀더 모두 치환됨"
fi

# ── 2. e2e/tsconfig.json 유효 JSON ──
if node -e "JSON.parse(require('fs').readFileSync('$TMP/e2e-tsconfig.json','utf8'))" 2>/dev/null; then
  echo "✅ e2e/tsconfig.json 유효한 JSON"
else
  echo "❌ e2e/tsconfig.json JSON 파싱 실패"; FAILS=$((FAILS + 1))
fi

# ── 3. 네이밍 컨벤션 비충돌 (load-bearing 결정 회귀 앵커) ──
node -e '
  const vitestCollects   = (f) => /\.(test|spec)\.[cm]?[jt]sx?$/.test(f);  // Vitest 기본 include 의미
  const playwrightMatches = (f) => /\.e2e\.tsx?$/.test(f);                  // Playwright testMatch **/*.e2e.ts
  const checks = [
    ["smoke.e2e.ts",   false, true],   // e2e 스펙: Vitest 미수집, Playwright 수집
    ["Button.test.ts", true,  false],  // 단위 테스트: Vitest 수집, Playwright 미수집
    ["util.spec.ts",   true,  false],
  ];
  let bad = 0;
  for (const [f, wantV, wantP] of checks) {
    const v = vitestCollects(f), p = playwrightMatches(f);
    if (v !== wantV || p !== wantP) { console.log(`❌ ${f}: vitest=${v}(기대 ${wantV}) playwright=${p}(기대 ${wantP})`); bad++; }
    else { console.log(`✅ ${f}: vitest=${v} playwright=${p}`); }
  }
  process.exit(bad === 0 ? 0 : 1);
'
if [ $? -ne 0 ]; then FAILS=$((FAILS + 1)); fi

echo ""
echo "═══ 판정 ═══"
if [ "$FAILS" -eq 0 ]; then
  echo "✅ 전체 통과 — E2E 템플릿 렌더 + 네이밍 비충돌 정상"; exit 0
else
  echo "❌ ${FAILS}건 실패"; exit 1
fi
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bash test/e2e-fixtures.sh`
Expected: FAIL — `templates/playwright.config.ts` 등이 없어 sed/cp가 빈 파일 생성 또는 에러, 또는 잔여 검사/JSON 검사 실패로 `❌ ...건 실패`, exit 1.

- [ ] **Step 3: `templates/playwright.config.ts` 생성**

```ts
import { defineConfig, devices } from '@playwright/test';

// 하네스 생성 — 브라우저 E2E 설정 (harness-setup E2E 스캐폴드 모듈, managed).
// 네이밍 컨벤션: E2E 스펙은 *.e2e.ts 다. Vitest 기본 글롭(**/*.{test,spec}.ts)이
// 이 파일들을 수집하지 않으므로 vitest.config 수정이 불필요하다.
export default defineConfig({
  testDir: 'e2e/specs',
  testMatch: '**/*.e2e.ts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: 'http://localhost:{{DEV_SERVER_PORT}}',
    trace: 'on-first-retry',
  },
  // 개발 서버 자동 기동: 로컬은 떠 있으면 재사용, CI는 항상 새로 띄운다.
  webServer: {
    command: '{{DEV_SERVER_COMMAND}}',
    url: 'http://localhost:{{DEV_SERVER_PORT}}',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});

// ── 프로젝트별 셋업 가이드 (앱에 따라 직접 채우세요 — 하네스는 일반화하지 않음) ──
// 1. 부팅 시 환경변수가 필수인 앱: webServer.env 또는 더미 .env로 주입.
// 2. 외부 인증(예: Supabase auth): per-test fixture에서 '**/auth/v1/**' 등을 route-block.
// 3. 시간 의존 UI: e2e/fixtures/test.ts의 clock 훅 사용 (날짜 테스트에 한정).
```

- [ ] **Step 4: `templates/e2e/tsconfig.json` 생성**

```json
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "composite": false,
    "noEmit": true,
    "types": ["@playwright/test", "node"]
  },
  "include": ["**/*.ts"]
}
```

- [ ] **Step 5: `templates/e2e/fixtures/test.ts` 생성**

```ts
import { test as base, expect } from '@playwright/test';
import { seed } from './seed';

// 하네스 생성 — per-test base fixture (custom: 1회 생성, 자유 수정).
// Playwright의 test를 확장한다. 각 테스트는 fresh context로 시작한다(Playwright 기본).
// 시드가 필요하면 아래 주석을 참고해 seed()를 호출하는 fixture를 추가한다.
export const test = base.extend({
  // page: async ({ page }, use) => {
  //   await page.addInitScript(seed, /* 시드 데이터 */);
  //   await use(page);
  // },
});

export { expect, seed };
```

- [ ] **Step 6: `templates/e2e/fixtures/seed.ts` 생성**

```ts
// 하네스 생성 — 시드 헬퍼 (custom: 1회 생성, 앱에 맞게 채우세요).
//
// 이 함수는 page.addInitScript로 브라우저 컨텍스트에 주입되어 앱 부팅 전에 실행된다.
// 가장 견고한 시드 방법은 앱의 영속 저장소(localStorage 등)에 직접 봉투를 주입하는 것이다.
//
// 예시 (Zustand persist 등 — 앱 구조에 맞게 수정):
//   export function seed(payload: { key: string; value: unknown }) {
//     window.localStorage.setItem(payload.key, JSON.stringify(payload.value));
//   }
// 주의: 직렬화 형태(DTO 배열 + version 필드 등)와 키 이름은 앱의 persist 설정과 정확히 일치해야 한다.
export function seed(_payload: unknown): void {
  // (앱별) 위 예시를 참고해 시드 로직을 구현하세요. 시드가 불필요하면 사용하지 않아도 됩니다.
}
```

- [ ] **Step 7: `templates/e2e/specs/smoke.e2e.ts` 생성**

```ts
import { test, expect } from '../fixtures/test';

// 하네스 생성 — 스타터 스모크 (custom: 시작점, 자유 수정).
// "툴체인이 동작하는가"를 확인하는 제너릭 테스트다.
// 앱 부팅에 환경변수/인증이 필요하면 e2e/fixtures/test.ts에서 처리한 뒤 통과시킨다.
test('앱이 로드된다 (스모크)', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('body')).toBeVisible();
});
```

- [ ] **Step 8: 테스트 실행 → 통과 확인**

Run: `bash test/e2e-fixtures.sh`
Expected: PASS — `✅ 플레이스홀더 모두 치환됨`, `✅ e2e/tsconfig.json 유효한 JSON`, 3개 네이밍 체크 `✅`, `✅ 전체 통과`, exit 0.

- [ ] **Step 9: 커밋**

```bash
git add test/e2e-fixtures.sh templates/playwright.config.ts templates/e2e/
git commit -m "feat(templates): E2E 스캐폴드 템플릿 5종 + 골든 픽스처 (이슈 #12 증분 1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: harness-scaffold 입력 스키마 + 매니페스트 계약

**Files:**
- Modify: `harness-scaffold/SKILL.md` (§4 입력 스키마 ~143, §4 필드 참조 규칙 ~175, §5.13 생성 규칙 1 ~885, §10.1 카테고리 테이블 ~1293)

- [ ] **Step 1: §4 입력 스키마에 `e2e` 블록 추가**

`harness-scaffold/SKILL.md`의 `eslintAssist` 블록(`"maxLines": 300` + 닫는 `}`) 다음에 삽입. `eslintAssist` 블록은:

```json
  "eslintAssist": {
    "enabled": true,
    "configFile": "eslint.config.js",
    "configFormat": "flat",
    "layerRules": true,
    "maxLines": 300
  },
```

이 블록 바로 뒤에 추가:

```json
  "e2e": {
    "enabled": true,
    "framework": "playwright",
    "playwrightVersion": "1.48.0"
  },
```

- [ ] **Step 2: §4 필드 참조 규칙에 e2e 항목 추가**

§4 "필드 참조 규칙" 목록(`integrations`는 ... 항목 뒤)에 추가:

```markdown
- `e2e`는 사용자가 문답에서 옵트인한 경우에만 존재한다 (선택 필드). 생략 시 E2E 스캐폴드 산출물을 생성하지 않는다 (§ 5.17). 프론트엔드 프로젝트에서만 제안된다. `playwrightVersion`은 핀 버전이며 § 5.5가 package.json devDependencies에 직접 사용한다 (`scripts.lint:arch`와 동일하게 프로필에서 읽음 — 새 플레이스홀더 아님).
```

- [ ] **Step 3: §5.13 생성 규칙 1(profile 부분집합)에 e2e 추가**

§5.13 생성 규칙 1의 필드 목록 끝(`integrations`(있는 경우만).) 직전에 `e2e`(있는 경우만)을 추가한다. 변경 후:

```markdown
... `eslintAssist`(있는 경우만), `sharedDirs`(있는 경우만), `e2e`(있는 경우만), `integrations`(있는 경우만).
```

- [ ] **Step 4: §10.1 파일별 분류 테이블에 e2e 파일 행 추가**

§10.1 "파일별 분류" 테이블의 마지막 행(25 ESLint 설정) 뒤에 추가:

```markdown
| 26 | `playwright.config.ts` | managed | 템플릿 기반 E2E 설정 (e2e 옵트인 시에만) |
| 27 | `e2e/tsconfig.json` | managed | 템플릿 기반 e2e 컴파일 경계 (e2e 옵트인 시에만) |
| 28 | `e2e/fixtures/test.ts` | custom | per-test fixture, 사용자가 시드 훅 추가 (e2e 옵트인 시에만) |
| 29 | `e2e/fixtures/seed.ts` | custom | 앱별 시드 로직, 사용자 소유 (e2e 옵트인 시에만) |
| 30 | `e2e/specs/smoke.e2e.ts` | custom | 스타터 스모크, 사용자가 회귀 스펙 축적 (e2e 옵트인 시에만) |
```

- [ ] **Step 5: §4 입력 스키마 매니페스트 예시의 e2e 누락 무영향 확인**

§5.13의 manifest 예시 `profile` 블록(`eslintAssist` 포함, ~843-849)은 e2e 옵트인 시에만 `e2e`를 포함한다. 예시는 변경 불필요(eslintAssist만 보여주는 부분 예시) — 단 생성 규칙 1(Step 3)이 SSoT이므로 일관됨을 확인한다.

- [ ] **Step 6: 정합성 검증 (grep)**

Run: `grep -n '"e2e"' harness-scaffold/SKILL.md`
Expected: §4 입력 스키마(1개) 라인 출력. (생성 규칙·테이블은 백틱 `e2e` 표기라 별도)
Run: `grep -n 'playwright.config.ts\|e2e/tsconfig.json\|e2e/fixtures\|e2e/specs' harness-scaffold/SKILL.md`
Expected: §10.1 테이블 5개 행 출력.

- [ ] **Step 7: 커밋**

```bash
git add harness-scaffold/SKILL.md
git commit -m "feat(skill): harness-scaffold e2e 입력 스키마 + manifest 카테고리 계약

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: harness-scaffold 생성 단계(§5.17) + package.json 머지 확장 + 생성 순서 + 검증

**Files:**
- Modify: `harness-scaffold/SKILL.md` (§5 생성 순서 ~214, §5.5 package.json ~503, §5.17 신규 ~997, §6 검증 ~1043)

- [ ] **Step 1: §5 생성 순서에 E2E 모듈 단계 삽입 + 재번호**

§5 생성 순서 코드 블록에서 18 다음에 새 단계를 삽입하고 19·20을 21까지 재번호:

```
18. package.json scripts 추가 (harness:check 포함; e2e 옵트인 시 test:e2e + @playwright/test devDep — § 5.5)
19. E2E 스캐폴드 모듈 (e2e 옵트인 시에만 — § 5.17): playwright.config.ts + e2e/ 디렉토리
20. ESLint 보조 규칙 수정 (eslintAssist 옵트인 시에만 — § 5.15)
21. .harness-manifest.json (버전 추적 매니페스트 — § 5.13, 항상 마지막 — Stop hook 종료 조건)
```

- [ ] **Step 2: §5.5 package.json 머지 스크립트에 e2e 분기 추가**

§5.5 "다음 항목만 추가한다" 목록에 추가:

```markdown
  - `test:e2e` (조건부): 프로필에 `e2e.enabled`가 있을 때만 추가 — `playwright test`
```

그리고 §5.5의 Node 스크립트 본문을 e2e 분기를 포함하도록 교체한다. 기존 `toAdd` 블록과 마지막 writeFile 사이를 다음으로 확장:

```bash
node -e "
const fs = require('fs');
const pkg = require('./package.json');
const toAdd = {
  'lint:arch': '{프로필에서 가져온 lint:arch 명령}',
  'validate': '{프로필에서 가져온 validate 명령}',
  'doc:check': '{프로필에서 가져온 doc:check 명령}',
  'harness:check': 'bash scripts/harness-check.sh'
};
// 기존 test가 watch 기본일 때만: toAdd['test:run'] = '{단발 실행 명령, 예: vitest run}';
// e2e 옵트인 시에만: toAdd['test:e2e'] = 'playwright test';
let changed = false;
for (const [key, val] of Object.entries(toAdd)) {
  if (!pkg.scripts[key]) { pkg.scripts[key] = val; changed = true; }
}
// e2e 옵트인 시: @playwright/test devDependency add-only 머지 (설치는 실행하지 않음 — Phase 4 안내)
// const PW_VERSION = '{프로필 e2e.playwrightVersion}';
// pkg.devDependencies = pkg.devDependencies || {};
// if (!pkg.devDependencies['@playwright/test']) { pkg.devDependencies['@playwright/test'] = '^' + PW_VERSION; changed = true; }
if (changed) {
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
  console.log('✅ package.json 업데이트 완료');
} else {
  console.log('ℹ️ 추가할 항목 없음 (이미 존재)');
}
"
```

그리고 §5.5에 e2e 머지 규칙 문단을 추가한다 (validate 조합 규칙 위):

```markdown
**E2E 머지 (e2e 옵트인 시에만)**:
- `scripts.test:e2e` ← `playwright test` (키 부재 시에만 추가)
- `devDependencies['@playwright/test']` ← `^{profile.e2e.playwrightVersion}` (키 부재 시에만 추가). **install은 실행하지 않는다** — Phase 4에서 `npm i && npx playwright install` 안내
- `test:e2e`는 **validate에 포함하지 않는다** — 전체 E2E는 빠른 검증 루프와 분리한다 (브라우저·dev 서버 기동 비용). E2E를 TDD 빠른 루프에 편입하는 것은 증분 2(@critical + pre-push)에서 다룬다
```

- [ ] **Step 3: §5.17 신규 섹션 작성**

§5.16(외부 통합 연계 렌더링) 다음, `---` 앞에 새 섹션 추가:

```markdown
### 5.17 E2E 스캐폴드 모듈 (옵트인)

프로필에 `e2e` 필드가 있고 `enabled: true`일 때만 실행한다. 필드가 없으면 이 단계 전체를 건너뛴다 (산출물 0건).

> **원칙 준수**: 비침습 — 기존 `vitest.config`·`tsconfig`를 수정하지 않는다. 새 파일만 생성하고, package.json은 § 5.5의 add-only 머지만 수행한다.

#### 생성 파일

| 파일 | 카테고리 | 템플릿 | 치환 |
|------|---------|--------|------|
| `playwright.config.ts` | managed | `templates/playwright.config.ts` | `{{DEV_SERVER_COMMAND}}` ← devServer.command, `{{DEV_SERVER_PORT}}` ← devServer.port |
| `e2e/tsconfig.json` | managed | `templates/e2e/tsconfig.json` | 없음 |
| `e2e/fixtures/test.ts` | custom | `templates/e2e/fixtures/test.ts` | 없음 |
| `e2e/fixtures/seed.ts` | custom | `templates/e2e/fixtures/seed.ts` | 없음 |
| `e2e/specs/smoke.e2e.ts` | custom | `templates/e2e/specs/smoke.e2e.ts` | 없음 |

#### 규칙

- `playwright.config.ts`의 `testMatch`는 `**/*.e2e.ts`이고, Vitest 기본 글롭(`**/*.{test,spec}.ts`)은 `.e2e.ts`를 수집하지 않는다 — 따라서 vitest.config 수정이 불필요하다 (이슈 #12의 load-bearing 결정).
- `e2e/tsconfig.json`은 root tsconfig를 `extends`하고 e2e 디렉토리만 컴파일한다. **root tsconfig는 수정하지 않는다.** root의 include가 e2e를 포함하면 harness-check ⑧이 경고한다 (§ 5.14).
- custom 파일(fixtures/seed/smoke)은 이미 존재하면 덮어쓰지 않는다 (사용자 소유). managed 파일(config/tsconfig)은 § 12.6 자동 감지로 템플릿 변경을 전파한다.
- E2E 그린은 앱별 부팅(env/route-block)에 의존하므로 **스위트를 실행하지 않는다** — 구조(파일·스크립트 존재)만 보장한다 (의미 비보장, harness-checklist § 7 일관).
```

- [ ] **Step 4: §6 검증 체크리스트에 e2e 항목 추가**

§6 검증 코드 블록의 6.15 다음에 추가:

```bash
# 6.16 E2E 스캐폴드 검증 (e2e 옵트인 시에만 실행)
if [ -f playwright.config.ts ]; then
  ls -la playwright.config.ts e2e/tsconfig.json e2e/specs/smoke.e2e.ts 2>&1
  node -e "const p=require('./package.json'); console.log(p.scripts['test:e2e'] ? '✅ test:e2e script' : '❌ test:e2e 누락'); console.log(p.devDependencies && p.devDependencies['@playwright/test'] ? '✅ @playwright/test devDep' : '⚠️ @playwright/test devDep 미기록');"
  grep -q '{{' playwright.config.ts && echo "❌ playwright.config.ts 미치환 플레이스홀더" || echo "✅ playwright.config.ts 치환 완료"
fi
```

그리고 §6.11의 플레이스홀더 검사 대상에 `playwright.config.ts`가 e2e 옵트인 시 포함되도록 6.16에서 별도 검사함을 위 블록이 담당한다 (6.11 자체는 변경 불필요 — e2e 미옵트인 시 파일 부재).

- [ ] **Step 5: 정합성 검증 (grep)**

Run: `grep -n '§ 5.17\|5.17 E2E\|test:e2e\|playwright.config.ts' harness-scaffold/SKILL.md`
Expected: 생성 순서 19, §5.5 머지 규칙, §5.17 섹션, §6.16 검증에서 출력.
Run: `grep -c '^### 5\.' harness-scaffold/SKILL.md` (섹션 번호 중복 없음 확인 — 5.17이 새로 1개)

- [ ] **Step 6: 커밋**

```bash
git add harness-scaffold/SKILL.md
git commit -m "feat(skill): harness-scaffold E2E 생성 단계(§5.17) + package.json 머지 확장

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: harness-scaffold Phase 4 카탈로그 줄 + 렌더링 규칙

**Files:**
- Modify: `harness-scaffold/SKILL.md` (§7 "이제 할 수 있는 일" ~1190, 렌더링 규칙 ~1202)

- [ ] **Step 1: "이제 할 수 있는 일" 카탈로그에 E2E 줄 추가**

§7 카탈로그 블록에서 "보조 스킬(brainstorming 등) → ..." 줄 다음, `> 위 줄은 정본을 가리킬 뿐 ...` 직전에 추가:

```markdown
- 브라우저 E2E 회귀 작성 → `npm run test:e2e` (상세: e2e/, playwright.config.ts) — e2e 옵트인 시에만 표시
```

- [ ] **Step 2: 카탈로그 렌더링 규칙에 E2E 항목 추가**

§7 "카탈로그 렌더링 규칙"의 "검증 게이트 · 자가진단 · ..." 항목 다음에 추가:

```markdown
- **브라우저 E2E 줄**: `e2e.enabled === true`이고 § 5.17 산출물(`playwright.config.ts`)이 생성된 경우에만 렌더 — 산출물 생성을 결정한 바로 그 신호를 재사용하는 순수 투영. 미옵트인 시 줄 자체를 생략한다 (미와이어 능력 광고 불가).
```

- [ ] **Step 3: 정합성 검증 (grep)**

Run: `grep -n '브라우저 E2E' harness-scaffold/SKILL.md`
Expected: 카탈로그 줄 1개 + 렌더링 규칙 1개 = 2개 라인.

- [ ] **Step 4: 커밋**

```bash
git add harness-scaffold/SKILL.md
git commit -m "feat(skill): Phase 4 카탈로그 E2E 능력 줄 (순수 투영, e2e.enabled 게이트)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: SKILL.md(분석) — 출력 스키마 + 감지 + 옵트인 질문 + 절대 규칙

**Files:**
- Modify: `SKILL.md` (출력 스키마 ~604, 필드 규칙 ~647, Step 1.4 ~179, §4.2 옵트인 ~351, §7 절대 규칙 ~787)

- [ ] **Step 1: 출력 스키마에 `e2e` 블록 추가 (계약 일치)**

`SKILL.md`의 `eslintAssist` 블록(`"maxLines": 300` + 닫는 `}`) 다음에 Task 2 Step 1과 **동일한** e2e 블록을 삽입:

```json
  "e2e": {
    "enabled": true,
    "framework": "playwright",
    "playwrightVersion": "1.48.0"
  },
```

- [ ] **Step 2: 필드 규칙 테이블에 e2e 행 추가**

`SKILL.md`의 필드 규칙 테이블에서 `eslintAssist` 행 다음에 추가:

```markdown
| `e2e` (선택) | Step 1.4 감지 + Step 4 옵트인 | 생략 시 E2E 모듈 미생성. **프론트엔드 프로젝트에서만 제안** (testFramework.e2e가 playwright이거나 UI 프레임워크 감지). `playwrightVersion`은 핀 버전 — harness-scaffold § 5.5가 devDependencies에 직접 사용. 프리셋 비대상 (감지+문답 전용) |
```

- [ ] **Step 3: Step 1.4 감지 노트 추가**

`SKILL.md` Step 1.4 "확인 항목"의 마지막 줄(ESLint 설정 파일 ... 트리거한다) 다음에 추가:

```markdown
- 프론트엔드 신호(테스트 프레임워크가 playwright이거나, stack에 UI 프레임워크 — react/react-dom/vue/svelte/solid-js/@angular/core — 감지)가 있으면 § 4.2의 E2E 계층 질문(옵트인)을 트리거한다. 백엔드 전용(express 등)은 트리거하지 않는다
```

- [ ] **Step 4: §4.2에 E2E 계층 옵트인 질문 블록 추가**

`SKILL.md` §4.2에서 "ESLint 보조 규칙 관련" 블록 다음에 추가:

```markdown
**E2E 계층 (Playwright) 관련** (Step 1.4에서 프론트엔드 신호가 감지된 경우에만, 우선순위 5 — 옵트인):
- "브라우저 E2E 계층(Playwright)을 셋업할까요? jsdom 단위 테스트가 못 잡는 상호작용 회귀(편집모드 재오픈, 드래그 오발동, StrictMode 이중 effect 등)를 실제 브라우저로 자동화합니다. `playwright.config.ts`와 `e2e/` 디렉토리·스모크 스펙을 생성하고, package.json에 `test:e2e` 스크립트와 `@playwright/test` 의존성을 추가합니다 (**설치 명령은 안내만 — 자동 실행하지 않음**). `e2e/`는 src 밖이라 레이어 린터·Vitest와 충돌하지 않습니다."
- 동의하면 프로필에 `e2e` 필드(enabled, framework: "playwright", playwrightVersion)를 기록한다. playwrightVersion은 현재 stable 버전으로 채운다. 거부하거나 답이 없으면 필드를 생략한다 (E2E 모듈 미생성)
```

- [ ] **Step 5: §7 절대 규칙에 e2e 옵트인 수정 명시**

`SKILL.md` §7 "파일 보호"의 "기존 설정 파일을 덮어쓰지 않는다" 줄에서 옵트인 수정 목록에 e2e를 추가. 변경 후:

```markdown
- 기존 설정 파일을 덮어쓰지 않는다 — 이 스킬은 어떤 파일도 수정하지 않는다. 옵트인된 수정은 `/harness-scaffold`가 수행한다 (package.json scripts·E2E devDependency: harness-scaffold/SKILL.md § 5.5, E2E 스캐폴드: § 5.17, ESLint 보조 규칙: 옵트인 질문은 이 파일 § 4.2, 실행은 harness-scaffold/SKILL.md § 5.15)
```

- [ ] **Step 6: 정합성 검증 — 프로필 스키마 계약 일치 (양쪽 SKILL.md)**

Run:
```bash
diff <(grep -A4 '"e2e": {' SKILL.md | head -5) <(grep -A4 '"e2e": {' harness-scaffold/SKILL.md | head -5)
```
Expected: 차이 없음 (출력 없음) — 두 스키마의 e2e 블록이 동일.
Run: `grep -n 'E2E 계층\|프론트엔드 신호' SKILL.md`
Expected: Step 1.4 감지 노트 + §4.2 질문 블록 출력.

- [ ] **Step 7: 커밋**

```bash
git add SKILL.md
git commit -m "feat(skill): SKILL.md e2e 출력 스키마 + 프론트엔드 감지 + 옵트인 질문

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: harness-check.sh — ⑧ E2E 구조 검사 (경고 전용, 자기 게이트)

**Files:**
- Modify: `templates/harness-check.sh` (⑦ 다음, 종합 판정 앞)
- Modify: `harness-scaffold/SKILL.md` §5.14 (검사 항목 설명 ~915)
- Test: `test/e2e-fixtures.sh` (harness-check ⑧ 동작 케이스 추가)

- [ ] **Step 1: 테스트에 harness-check ⑧ 케이스 추가 (실패 확인)**

`test/e2e-fixtures.sh`의 판정 직전(`echo "═══ 판정 ═══"` 앞)에 추가:

```bash
# ── 4. harness-check.sh ⑧ E2E 구조 검사 (자기 게이트: playwright.config.ts 존재 시에만 동작) ──
HC="$TEMPLATES/harness-check.sh"
# (a) playwright.config.ts 없는 디렉토리 → ⑧ 출력 없음(스킵)
WORK="$TMP/no-e2e"; mkdir -p "$WORK"
sed -e "s#{{LINT_ARCH_COMMAND}}#true#g" -e "s#{{VALIDATE_COMMAND}}#true#g" \
    -e "s#{{DOC_CHECK_COMMAND}}#true#g" -e 's#{{PATH_ALIAS_LIST}}#"@/"#g' "$HC" > "$WORK/hc.sh"
( cd "$WORK" && bash hc.sh 2>&1 | grep -q "── ⑧" ) && { echo "❌ e2e 없는데 ⑧ 실행됨"; FAILS=$((FAILS+1)); } || echo "✅ e2e 미설치 시 ⑧ 스킵"
# (b) playwright.config.ts 있는 디렉토리 → ⑧ 출력 존재
WORK2="$TMP/has-e2e"; mkdir -p "$WORK2/e2e/specs"
cp "$WORK/hc.sh" "$WORK2/hc.sh"; : > "$WORK2/playwright.config.ts"; : > "$WORK2/e2e/specs/smoke.e2e.ts"
echo '{"scripts":{"test:e2e":"playwright test"}}' > "$WORK2/package.json"
( cd "$WORK2" && bash hc.sh 2>&1 | grep -q "── ⑧" ) && echo "✅ e2e 설치 시 ⑧ 실행" || { echo "❌ e2e 있는데 ⑧ 미실행"; FAILS=$((FAILS+1)); }
```

Run: `bash test/e2e-fixtures.sh`
Expected: FAIL — harness-check.sh에 ⑧ 블록이 없어 "── ⑧" 미출력 → (b) 케이스 실패, exit 1.

- [ ] **Step 2: harness-check.sh에 ⑧ 블록 추가**

`templates/harness-check.sh`의 ⑦ 블록(tsconfig paths) 다음, `# 종합 판정` 앞에 추가:

```bash
# ⑧ E2E 스캐폴드 구조 (경고만 — playwright.config.ts 존재 시에만 검사)
if [ -f playwright.config.ts ]; then
  echo ""
  echo "── ⑧ E2E 스캐폴드 ──"
  if node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts['test:e2e'] ? 0 : 1)" 2>/dev/null; then
    echo "✅ test:e2e 스크립트 존재"
  else
    echo "⚠️ test:e2e 스크립트 미발견 — package.json 확인 권장"
  fi
  if [ -d e2e/specs ]; then
    echo "✅ e2e/specs 디렉토리 존재"
  else
    echo "⚠️ e2e/specs 디렉토리 미발견"
  fi
  # root tsconfig가 e2e를 포함하면 tsc가 e2e를 잘못 컴파일할 수 있음 (tsconfig는 수정하지 않음 — 경고만)
  if [ -f tsconfig.json ]; then
    if ! grep -q '"include"' tsconfig.json 2>/dev/null; then
      echo "⚠️ tsconfig.json에 include 없음 — e2e/가 root 컴파일에 섞일 수 있습니다. root tsconfig exclude에 \"e2e\" 추가 권장 (하네스는 tsconfig를 수정하지 않음)"
    elif grep -q '"e2e' tsconfig.json 2>/dev/null; then
      echo "⚠️ tsconfig.json include가 e2e를 포함하는 듯합니다 — exclude에 \"e2e\" 추가 권장"
    fi
  fi
fi
```

(⑧은 `STRUCT_FAIL`/`QUALITY_FAIL`을 건드리지 않으므로 exit code에 영향 없음 — ⑥⑦과 동일한 경고 전용.)

- [ ] **Step 3: 테스트 실행 → 통과 확인**

Run: `bash test/e2e-fixtures.sh`
Expected: PASS — `✅ e2e 미설치 시 ⑧ 스킵`, `✅ e2e 설치 시 ⑧ 실행`, `✅ 전체 통과`, exit 0.

- [ ] **Step 4: §5.14 검사 항목 설명 업데이트**

`harness-scaffold/SKILL.md` §5.14 "검사 7항목과 exit 규칙"을 "검사 8항목"으로 바꾸고 ⑧ 설명 추가:

```markdown
  - ⑥ doc:check 실행, ⑦ tsconfig paths에 pathAlias 존재, ⑧ E2E 스캐폴드 구조(playwright.config.ts 존재 시) — **경고 전용**. exit code에 영향 없음
```

(기존 "검사 7항목" 문구를 "검사 8항목"으로 수정. harness-check.sh 헤더 주석의 "경고 전용 (⑥⑦)"도 "(⑥⑦⑧)"로 수정.)

- [ ] **Step 5: harness-check.sh 헤더 주석 업데이트**

`templates/harness-check.sh` 헤더의 `#   경고 전용 (⑥⑦)   — exit code에 영향 없음`을 `#   경고 전용 (⑥⑦⑧) — exit code에 영향 없음`으로 수정.

- [ ] **Step 6: 커밋**

```bash
git add templates/harness-check.sh harness-scaffold/SKILL.md test/e2e-fixtures.sh
git commit -m "feat(templates): harness-check ⑧ E2E 구조 검사 (경고 전용, 자기 게이트)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: references 업데이트 + 버전 범프 1.11.0

**Files:**
- Modify: `references/harness-checklist.md` (§4.2 ~117)
- Modify: `references/versioning-policy.md` (§1 카운트 확인)
- Modify: `references/project-context.md` (§4 버전 히스토리)
- Modify: `SKILL.md`, `harness-scaffold/SKILL.md` (스키마 version 1.10.0 → 1.11.0)

- [ ] **Step 1: harness-checklist.md §4.2에 E2E 구현 경로 명시**

§4.2의 "Level 4 E2E: 브라우저 자동화로 실제 시나리오 재현 (수분)" 항목 뒤에 한 줄 추가:

```markdown
- [ ] (e2e 옵트인 시) `playwright.config.ts` + `e2e/` 스캐폴드 존재 — harness-setup E2E 모듈(§ 5.17)이 생성. 구조만 보장하며 스위트 통과(의미)는 앱별 부팅에 의존
```

- [ ] **Step 2: versioning-policy.md §1 카운트 확인 주석**

§1 Public API 테이블의 "생성 파일 구조 | 템플릿 → 생성된 19개 파일" 행 설명을 확인하고, e2e가 옵트인 추가임을 반영하여 다음으로 수정:

```markdown
| **생성 파일 구조** | 템플릿 → 생성된 19개 파일 (+ 옵트인 시 ESLint·E2E) | AI 에이전트, 사용자 | 보통 |
```

(플레이스홀더 29개는 불변 — Task 3에서 새 `{{}}` 미도입 확인.)

- [ ] **Step 3: 스키마 version 범프 (양쪽 SKILL.md)**

Run:
```bash
sed -i '' 's/"version": "1.10.0"/"version": "1.11.0"/' SKILL.md harness-scaffold/SKILL.md
grep -rn '"version": "1.1[01].0"' SKILL.md harness-scaffold/SKILL.md
```
Expected: SKILL.md 출력 스키마, harness-scaffold 입력 스키마 + manifest 예시의 version이 모두 "1.11.0".
주의: manifest 예시(`harness.skillVersion` 등)에 별도 버전 문자열이 있으면 함께 1.11.0으로 맞춘다 (grep으로 1.10.0 잔존 확인).

Run: `grep -rn '1\.10\.0' SKILL.md harness-scaffold/SKILL.md`
Expected: 스키마 외 잔존 없음 (역사적 참조가 있으면 보존, 스키마 예시값만 범프).

- [ ] **Step 4: project-context.md §4 버전 히스토리 항목 추가**

§4 버전 히스토리 최상단(1.10.0 항목 위)에 추가:

```markdown
- **1.11.0** (2026-06-15) — E2E 스캐폴드 모듈 (이슈 #12 증분 1). 프론트엔드 옵트인으로 Playwright 기반 E2E 셋업(playwright.config.ts + e2e/ + test:e2e + @playwright/test devDep) 생성. Vitest 충돌은 `*.e2e.ts` 네이밍으로 회피(vitest.config 미수정), tsconfig 절대 비수정(e2e/tsconfig.json 자체 경계), config=managed/스타터=custom. harness-check ⑧ 구조 검사. 신규 플레이스홀더 0개, 마이그레이션 불필요(옵트인·생략 기본). 설계 정본: docs/superpowers/specs/2026-06-15-e2e-scaffold-module-design.md
```

- [ ] **Step 5: 정합성 검증**

Run: `bash test/e2e-fixtures.sh && bash test/run-fixtures.sh`
Expected: 둘 다 `✅ 전체 통과`, exit 0 (기존 골든 픽스처 회귀 없음).

- [ ] **Step 6: 커밋**

```bash
git add references/harness-checklist.md references/versioning-policy.md references/project-context.md SKILL.md harness-scaffold/SKILL.md
git commit -m "feat(refs,skill): 1.11.0 버전 범프 + E2E 구현 경로 반영

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 트래킹 갱신 + 최종 검증 + 수동 E2E 안내

**Files:**
- Modify: `.tracking/CHANGELOG.md`, `.tracking/HANDOFF.md`, `.tracking/TODO.md`

- [ ] **Step 1: CHANGELOG.md에 1.11.0 섹션 추가**

`.tracking/CHANGELOG.md` 최상단에 추가:

```markdown
## [1.11.0] — 2026-06-15

### Added (MINOR)
- E2E 스캐폴드 모듈 (이슈 #12 증분 1): 프로필 선택 필드 `e2e`(enabled/framework/playwrightVersion), 프론트엔드 감지 시 옵트인 질문, `templates/playwright.config.ts` + `templates/e2e/*`(tsconfig·fixtures·smoke), harness-scaffold §5.17 생성 단계, §5.5 package.json `test:e2e`+`@playwright/test` devDep add-only 머지, Phase 4 카탈로그 E2E 줄
- harness-check.sh ⑧ E2E 구조 검사 (경고 전용, playwright.config.ts 자기 게이트)
- `test/e2e-fixtures.sh` 골든 픽스처 — 템플릿 렌더 + Vitest 비충돌 회귀 앵커

### Changed (MINOR)
- 생성 순서 20 → 21단계 (E2E 모듈 단계 삽입), §10.1 파일 카테고리 테이블에 e2e 5개 행
- 버전 1.10.0 → 1.11.0

### 설계
- Vitest 충돌을 `*.e2e.ts` 네이밍으로 회피 → vitest.config 미수정 (이슈의 .spec.ts+exclude 설계에서 변경). tsconfig 절대 비수정 + e2e/tsconfig.json 자체 경계. 신규 플레이스홀더 0개, 마이그레이션 불필요(옵트인). 설계 정본: docs/superpowers/specs/2026-06-15-e2e-scaffold-module-design.md
```

- [ ] **Step 2: HANDOFF.md 갱신**

`.tracking/HANDOFF.md` § 1의 세션 목록에 Session 36 항목 추가(1.11.0 요약), "현재 버전: 1.10.0" → "1.11.0"으로 수정, P1-P10 테이블의 P7(검증 피드백 루프) 또는 관련 칸에 "E2E L4 스캐폴드(1.11.0, 옵트인)" 비고 추가.

- [ ] **Step 3: TODO.md 갱신**

`.tracking/TODO.md`에 이슈 #12 항목을 추가/갱신: 증분 1(E2E 스캐폴드 모듈) 완료 체크, 증분 2(TDD 배선+pre-push)·3(MCP)·4(프리셋+문서)를 후속 TODO로 등록.

- [ ] **Step 4: 전체 회귀 검증**

Run:
```bash
bash test/e2e-fixtures.sh
bash test/run-fixtures.sh
diff <(grep -A4 '"e2e": {' SKILL.md | head -5) <(grep -A4 '"e2e": {' harness-scaffold/SKILL.md | head -5)
grep -rn '{{.*}}' templates/playwright.config.ts templates/e2e/ | grep -v 'DEV_SERVER' || echo "✅ e2e 템플릿 미정의 플레이스홀더 없음"
```
Expected: 두 픽스처 `✅ 전체 통과`; diff 무출력(스키마 계약 일치); playwright.config.ts 외 e2e 템플릿에 플레이스홀더 없음.

- [ ] **Step 5: 커밋**

```bash
git add .tracking/
git commit -m "docs(tracking): 1.11.0 — E2E 스캐폴드 모듈 핸드오프·체인지로그·TODO

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: 수동 E2E 검증 안내 (자동화 불가 — 사용자/실프로젝트)**

스킬 자체의 통합 검증은 실제 프론트엔드 프로젝트에서만 가능하다 (CLAUDE.md "테스트" 절). 다음을 권고로 보고한다 (이 플랜에서 자동 실행하지 않음):
- 프론트엔드 프로젝트에서 `/harness-setup` → E2E 옵트인 "예" → `/harness-scaffold` → `playwright.config.ts`·`e2e/`·`test:e2e`·`@playwright/test` devDep 생성 확인
- 백엔드 프로젝트(express)에서 E2E 질문이 **생략**되는지 확인
- `npm i && npx playwright install && npm run test:e2e`로 스모크 그린 확인 (앱 부팅 의존성 없는 경우)
- `npm run harness:check`에서 ⑧ E2E 항목 출력 확인

이후 릴리스 태그는 사용자 승인 후 진행한다: `git tag v1.11.0`.

---

## Self-Review

**1. Spec coverage** (설계 §별 → 태스크 매핑):
- §2 헤드라인(1급 옵트인) → Task 2/5 (스키마 + 옵트인 질문) ✅
- §3 프로필 스키마 `e2e` → Task 2 Step 1, Task 5 Step 1 (양쪽 계약) ✅
- §4 감지 & 옵트인 → Task 5 Step 3·4 ✅
- §5 생성 파일 & 카테고리 → Task 1(템플릿), Task 2 Step 4(카테고리), Task 3(§5.17 생성) ✅
- §5.1 신규 플레이스홀더 0개 → Task 3(profile.e2e.playwrightVersion 직접 읽기) ✅
- §5.3 package.json 머지 확장 → Task 3 Step 2 ✅
- §6 3개 펜스 → Vitest(Task 1 네이밍 테스트), tsconfig(Task 6 ⑧ 경고), eslint(증분 1에서 별도 강제 안 함 — §5.15 기존 메커니즘 그대로, e2e 전용 override는 증분 2로 — **설계 §6 eslint "eslintAssist 켜진 경우 override"는 증분 1 범위에서 가이드 위임으로 축소**, 아래 GAP 참조) ⚠️
- §7 템플릿 내용 → Task 1 Step 3-7 ✅
- §8 harness-check + Phase 4 → Task 6(⑧), Task 4(카탈로그) ✅
- §9 업그레이드/마이그레이션 → 마이그레이션 불필요(옵트인) 명시, project-context/CHANGELOG에 기록. U1 재감지(기존 프론트 하네스에 e2e 옵트인 제안)는 **증분 1 범위 밖으로 명시** (setup 경로 우선; upgrade-offer는 후속) ⚠️
- §10 정합성 계약 → Task 5 Step 6(스키마 diff), Task 8 Step 4(전체) ✅
- §12 버전 → Task 7 ✅

**GAP 처리 (인라인 수정):**
- **eslint e2e override**: 설계 §6은 "eslintAssist 켜진 경우 마커로 e2e override 추가"였으나, 증분 1의 핵심 펜스는 Vitest(네이밍)·tsconfig(경고)이고 eslint override는 부가다. 증분 1에서는 **e2e 전용 eslint 수정을 하지 않는다** (e2e/는 기본 lint 대상 밖이거나 사용자가 관리). eslint-aware e2e 타깃은 증분 2(TDD 배선)에서 다룬다. → 이는 설계 §6 대비 **범위 축소**이며, Task 3 §5.17 규칙에 "eslint 수정 없음"을 명시했고 설계 §11 증분 2 범위와 일관. 별도 태스크 불필요.
- **U1 재감지(업그레이드 시 e2e 옵트인 제안)**: 증분 1은 setup 경로를 완성한다. 기존 하네스는 옵트인 생략 기본이라 **무영향**(깨지지 않음). "업그레이드 시 프론트 하네스에 e2e 제안"은 superpowers/consult의 U1 재감지 패턴을 따르되 **후속 작업**으로 분리 (이 플랜 범위 밖, TODO 등록). 이로써 증분 1이 독립적으로 동작하는 소프트웨어를 산출.

**2. Placeholder scan:** 플랜 내 "TBD/TODO/구현 later" 없음. 템플릿의 `{{DEV_SERVER_COMMAND}}`/`{{DEV_SERVER_PORT}}`는 의도된 치환 토큰. seed.ts의 "(앱별)" 주석은 사용자용 스타터 가이드(생성 하네스 문서 아님). 모든 코드 스텝에 실제 코드 포함.

**3. Type/이름 일관성:** 프로필 필드명 `e2e.enabled`/`e2e.framework`/`e2e.playwrightVersion`이 Task 2·5·3 전반에서 동일. 파일 경로 `playwright.config.ts`·`e2e/tsconfig.json`·`e2e/fixtures/{test,seed}.ts`·`e2e/specs/smoke.e2e.ts`가 Task 1·2·3·6 전반 일관. 스크립트명 `test:e2e` 일관. harness-check 항목번호 ⑧ 일관.

수정 완료 — 진행 준비됨.
