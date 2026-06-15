#!/bin/bash
# pre-push 훅 골든 픽스처 — 스킬 자체 검증 (생성 프로젝트와 무관, footprint 0)
#
# 목적: templates/githooks/pre-push 의 게이팅 분기를 결정적으로 검증 (mock playwright)
#   validate fail-fast / @critical 매칭 실행+exit 전파 / 0-매칭 no-op / 미설치 no-op / 마커 존재
#   + harness-check.sh ⑨ pre-push 게이트 활성/비활성 보고 (경고 전용)
#
# 요구: git, sh, node. 사용법: bash test/prepush-fixtures.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_TMPL="$ROOT/templates/githooks/pre-push"
HC="$ROOT/templates/harness-check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

# 워크 디렉토리 = git repo + 렌더된 훅 + mock playwright
# $1=validate_cmd  $2=mock_critical(0/1)  $3=mock_e2e_exit
make_work() {
  W="$(mktemp -d "$TMP/w.XXXXXX")"
  mkdir -p "$W/node_modules/.bin"
  ( cd "$W" && git init -q )
  sed -e "s#{{VALIDATE_COMMAND}}#$1#g" "$HOOK_TMPL" > "$W/pre-push"
  chmod +x "$W/pre-push"
  cat > "$W/node_modules/.bin/playwright" <<MOCK
#!/bin/sh
case "\$*" in
  *--list*) [ "$2" = "1" ] && echo "  [chromium] > e2e/specs/login.e2e.ts:3:1 > critical"; exit 0 ;;
  *) exit $3 ;;
esac
MOCK
  chmod +x "$W/node_modules/.bin/playwright"
  echo "$W"
}
run_hook() { ( cd "$1" && sh ./pre-push </dev/null >/dev/null 2>&1 ); echo $?; }

echo "═══ pre-push 훅 픽스처 ═══"

# 1. 렌더 후 미치환 플레이스홀더 없음
W=$(make_work true 0 0)
if grep -q '{{.*}}' "$W/pre-push"; then echo "❌ 미치환 플레이스홀더 잔존"; FAILS=$((FAILS+1)); else echo "✅ 플레이스홀더 치환됨"; fi

# 2. validate 실패 → exit 1 (push 차단), E2E 도달 전
W=$(make_work false 1 0); RC=$(run_hook "$W")
[ "$RC" = "1" ] && echo "✅ validate 실패 시 차단(exit 1)" || { echo "❌ validate 실패인데 exit $RC"; FAILS=$((FAILS+1)); }

# 3. @critical 매칭 + E2E 통과 → exit 0
W=$(make_work true 1 0); RC=$(run_hook "$W")
[ "$RC" = "0" ] && echo "✅ @critical 통과 시 exit 0" || { echo "❌ @critical 통과인데 exit $RC"; FAILS=$((FAILS+1)); }

# 4. @critical 매칭 + E2E 실패 → exit 1 (push 차단)
W=$(make_work true 1 1); RC=$(run_hook "$W")
[ "$RC" = "1" ] && echo "✅ @critical 실패 시 차단(exit 1)" || { echo "❌ @critical 실패인데 exit $RC"; FAILS=$((FAILS+1)); }

# 5. @critical 0-매칭 → no-op exit 0 (e2e_exit=1이어도 실행 안 됨)
W=$(make_work true 0 1); RC=$(run_hook "$W")
[ "$RC" = "0" ] && echo "✅ @critical 0개 시 no-op(exit 0)" || { echo "❌ 0-매칭인데 exit $RC"; FAILS=$((FAILS+1)); }

# 6. playwright 미설치 → no-op exit 0
W=$(make_work true 1 1); rm -f "$W/node_modules/.bin/playwright"; RC=$(run_hook "$W")
[ "$RC" = "0" ] && echo "✅ playwright 미설치 시 no-op(exit 0)" || { echo "❌ 미설치인데 exit $RC"; FAILS=$((FAILS+1)); }

# 7. 마커 블록 존재 (멱등 주입 앵커)
grep -q "harness-setup:e2e-prepush:start" "$HOOK_TMPL" && grep -q "harness-setup:e2e-prepush:end" "$HOOK_TMPL" \
  && echo "✅ 마커 블록 존재" || { echo "❌ 마커 누락"; FAILS=$((FAILS+1)); }

# ── harness-check ⑨ (Task 2에서 구현 — 그 전엔 8~10 실패가 정상) ──
render_hc() { sed -e "s#{{LINT_ARCH_COMMAND}}#true#g" -e "s#{{VALIDATE_COMMAND}}#true#g" \
  -e "s#{{DOC_CHECK_COMMAND}}#true#g" -e 's#{{PATH_ALIAS_LIST}}#"@/"#g' "$HC"; }

echo ""
echo "── harness-check ⑨ pre-push 게이트 ──"

# 8. .githooks/pre-push 있고 core.hooksPath 미설정 → ⑨ "비활성" 경고
W="$(mktemp -d "$TMP/w.XXXXXX")"; mkdir -p "$W/.githooks"; ( cd "$W" && git init -q )
render_hc > "$W/hc.sh"; cp "$HOOK_TMPL" "$W/.githooks/pre-push"
( cd "$W" && bash hc.sh 2>&1 | grep -q "비활성" ) && echo "✅ ⑨ 비활성 보고" || { echo "❌ ⑨ 비활성 미보고"; FAILS=$((FAILS+1)); }

# 9. core.hooksPath=.githooks → ⑨ "활성"
W="$(mktemp -d "$TMP/w.XXXXXX")"; mkdir -p "$W/.githooks"; ( cd "$W" && git init -q && git config core.hooksPath .githooks )
render_hc > "$W/hc.sh"; cp "$HOOK_TMPL" "$W/.githooks/pre-push"
( cd "$W" && bash hc.sh 2>&1 | grep -q "pre-push 게이트 활성" ) && echo "✅ ⑨ 활성 보고" || { echo "❌ ⑨ 활성 미보고"; FAILS=$((FAILS+1)); }

# 10. 훅도 hooksPath도 없음 → ⑨ 섹션 자체 생략
W="$(mktemp -d "$TMP/w.XXXXXX")"; ( cd "$W" && git init -q )
render_hc > "$W/hc.sh"
( cd "$W" && bash hc.sh 2>&1 | grep -q "── ⑨" ) && { echo "❌ pre-push 없는데 ⑨ 실행됨"; FAILS=$((FAILS+1)); } || echo "✅ pre-push 미설치 시 ⑨ 스킵"

echo ""
echo "═══ 판정 ═══"
[ "$FAILS" -eq 0 ] && { echo "✅ 전체 통과"; exit 0; } || { echo "❌ ${FAILS}건 실패"; exit 1; }
