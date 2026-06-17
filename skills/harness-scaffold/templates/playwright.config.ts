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
