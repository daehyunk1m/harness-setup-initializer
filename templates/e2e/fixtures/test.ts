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
