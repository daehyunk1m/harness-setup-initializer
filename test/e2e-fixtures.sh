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
# (c) e2e가 exclude된 tsconfig (권장 설정) → include 오탐 경고 없어야 함 (회귀 방지)
WORK3="$TMP/e2e-excluded"; mkdir -p "$WORK3/e2e/specs"
cp "$WORK/hc.sh" "$WORK3/hc.sh"; : > "$WORK3/playwright.config.ts"; : > "$WORK3/e2e/specs/smoke.e2e.ts"
echo '{"scripts":{"test:e2e":"playwright test"}}' > "$WORK3/package.json"
echo '{"include":["src"],"exclude":["e2e"]}' > "$WORK3/tsconfig.json"
( cd "$WORK3" && bash hc.sh 2>&1 | grep -q "include가 e2e를 포함" ) && { echo "❌ exclude된 e2e에 오탐 경고"; FAILS=$((FAILS+1)); } || echo "✅ e2e exclude 시 경고 없음 (오탐 회귀 방지)"
# (d) include가 e2e를 포함하는 tsconfig → 경고 있어야 함
WORK4="$TMP/e2e-included"; mkdir -p "$WORK4/e2e/specs"
cp "$WORK/hc.sh" "$WORK4/hc.sh"; : > "$WORK4/playwright.config.ts"; : > "$WORK4/e2e/specs/smoke.e2e.ts"
echo '{"scripts":{"test:e2e":"playwright test"}}' > "$WORK4/package.json"
echo '{"include":["src","e2e"]}' > "$WORK4/tsconfig.json"
( cd "$WORK4" && bash hc.sh 2>&1 | grep -q "include가 e2e를 포함" ) && echo "✅ include에 e2e 포함 시 경고" || { echo "❌ include e2e 경고 누락"; FAILS=$((FAILS+1)); }
# (e) 루트 광범위 글롭 include → 경고 있어야 함 (스펙 §8.1 "전체 디렉토리 컴파일")
WORK5="$TMP/glob-broad"; mkdir -p "$WORK5/e2e/specs"
cp "$WORK/hc.sh" "$WORK5/hc.sh"; : > "$WORK5/playwright.config.ts"; : > "$WORK5/e2e/specs/smoke.e2e.ts"
echo '{"scripts":{"test:e2e":"playwright test"}}' > "$WORK5/package.json"
echo '{"include":["**/*.ts"]}' > "$WORK5/tsconfig.json"
( cd "$WORK5" && bash hc.sh 2>&1 | grep -q "광범위 글롭" ) && echo "✅ 루트 광범위 글롭 시 경고" || { echo "❌ 광범위 글롭 경고 누락"; FAILS=$((FAILS+1)); }
# (f) src 한정 글롭 include → 경고 없어야 함 (오탐 회귀 방지)
WORK6="$TMP/glob-scoped"; mkdir -p "$WORK6/e2e/specs"
cp "$WORK/hc.sh" "$WORK6/hc.sh"; : > "$WORK6/playwright.config.ts"; : > "$WORK6/e2e/specs/smoke.e2e.ts"
echo '{"scripts":{"test:e2e":"playwright test"}}' > "$WORK6/package.json"
echo '{"include":["src/**/*.ts"]}' > "$WORK6/tsconfig.json"
( cd "$WORK6" && bash hc.sh 2>&1 | grep -Eq "광범위 글롭|e2e를 포함" ) && { echo "❌ src 한정 글롭에 오탐 경고"; FAILS=$((FAILS+1)); } || echo "✅ src 한정 글롭 시 경고 없음 (오탐 회귀 방지)"

echo ""
echo "═══ 판정 ═══"
if [ "$FAILS" -eq 0 ]; then
  echo "✅ 전체 통과 — E2E 템플릿 렌더 + 네이밍 비충돌 정상"; exit 0
else
  echo "❌ ${FAILS}건 실패"; exit 1
fi
