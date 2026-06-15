import { test, expect } from '../fixtures/test';

// 하네스 생성 — 스타터 스모크 (custom: 시작점, 자유 수정).
// "툴체인이 동작하는가"를 확인하는 제너릭 테스트다.
// 앱 부팅에 환경변수/인증이 필요하면 e2e/fixtures/test.ts에서 처리한 뒤 통과시킨다.
test('앱이 로드된다 (스모크)', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('body')).toBeVisible();
});
