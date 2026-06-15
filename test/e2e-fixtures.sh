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
