#!/bin/bash
# structural-test 템플릿 골든 픽스처 러너 — 스킬 자체 검증 (생성 프로젝트와 무관, footprint 0)
#
# 목적: templates/structural-test-{layer,fsd,domain}.ts가 실제로
#   - src-pass (허용 import만)  → exit 0 으로 통과시키고
#   - src-fail (금지 import 포함) → exit 1 으로 차단하는지
# 검증한다. 템플릿/렌더 로직 수정 시(또는 모델·버전 드리프트 시) 회귀를 잡는 앵커.
#
# 한계(no silent caps): 이 픽스처는 "템플릿 자체의 정확성"만 검증한다.
#   특정 프로젝트의 규칙 오설정(잘못된 LAYER_RULES 등)은 잡지 못한다 —
#   그것은 scaffold Phase 4의 의미론적 승인 게이트가 보완한다.
#
# 요구: node + npx (tsx는 npx가 자동 페치). 사용법: bash test/run-fixtures.sh

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$ROOT/skills/harness-scaffold/templates"
FIX="$ROOT/test/fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

if ! command -v npx >/dev/null 2>&1; then
  echo "❌ npx 없음 — node/npx 설치 후 재실행하세요"
  exit 1
fi

echo "═══ structural-test 골든 픽스처 ═══"

check() { # $1=arch dir, $2=template file
  local arch="$1" tpl="$2"
  for variant in pass fail; do
    local src="$FIX/$arch/src-$variant"
    if [ ! -d "$src" ]; then
      echo "❌ [$arch] src-$variant 픽스처 디렉토리 없음"
      FAILS=$((FAILS + 1))
      continue
    fi
    local script="$TMP/$arch-$variant.ts"
    # 템플릿 렌더: SRC_ROOT를 픽스처 절대경로로, Q2 마커를 enforced로 치환
    sed -e "s#const SRC_ROOT = './src';#const SRC_ROOT = '$src';#" \
        -e "s#{{Q2_ENFORCEMENT}}#enforced#" \
        "$TEMPLATES/$tpl" > "$script"
    npx --yes tsx "$script" >/dev/null 2>&1
    local code=$?
    if [ "$variant" = "pass" ] && [ "$code" -ne 0 ]; then
      echo "❌ [$arch] src-pass가 위반으로 판정됨 (exit $code, 기대 0) — 템플릿이 허용 import를 잘못 차단"
      FAILS=$((FAILS + 1))
    elif [ "$variant" = "fail" ] && [ "$code" -ne 1 ]; then
      echo "❌ [$arch] src-fail이 위반을 못 잡음 (exit $code, 기대 1) — 템플릿 강제 누락(Q2 회귀)"
      FAILS=$((FAILS + 1))
    else
      echo "✅ [$arch] src-$variant (exit $code)"
    fi
  done
}

check layer-based structural-test-layer.ts
check fsd structural-test-fsd.ts
check domain structural-test-domain.ts

echo ""
echo "═══ 판정 ═══"
if [ "$FAILS" -eq 0 ]; then
  echo "✅ 전체 통과 — 템플릿이 허용/금지 import를 정확히 구분합니다"
  exit 0
else
  echo "❌ ${FAILS}건 실패 — 템플릿 회귀 가능성 (릴리스 전 수정 필요)"
  exit 1
fi
