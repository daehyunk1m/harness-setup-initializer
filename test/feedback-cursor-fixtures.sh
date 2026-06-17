#!/bin/bash
# 피드백 보고 트리거 — 실행 스니펫 골든 픽스처 (스킬 자체 검증, footprint 0)
# 정본: session-routine.md(트리거) · harness-feedback/SKILL.md(post-cursor·전진·fingerprint)
set -u
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT; cd "$TMP"; FAILS=0
pass(){ echo "  ✅ $1"; }; fail(){ echo "  ❌ $1"; FAILS=$((FAILS+1)); }

# ── Snippet 1: 트리거 평가 (session-routine 세션 종료) ──
trigger_eval() {
node -e '
const fs=require("fs"), JL=".harness-friction.jsonl", CUR=".harness-feedback-cursor";
if(!fs.existsSync(JL)) process.exit(0);
const lines=fs.readFileSync(JL,"utf8").split("\n");
let processed=0;
if(fs.existsSync(CUR)){try{processed=JSON.parse(fs.readFileSync(CUR,"utf8")).processedLines||0}catch{}}
const SKIP=new Set(["infra-track-entry","session-incomplete"]);
let crit=0,high=0,med=0;const ev={};
for(let i=processed;i<lines.length;i++){
  const r=lines[i].trim(); if(!r) continue;
  let e; try{e=JSON.parse(r)}catch{continue}
  if(!e||SKIP.has(e.event)) continue;
  if(e.severity==="critical")crit++; else if(e.severity==="high")high++; else if(e.severity==="medium")med++;
  ev[e.event]=(ev[e.event]||0)+1;
}
const sameGe2=Object.values(ev).some(c=>c>=2);
if(crit>=1||sameGe2||high>=2){
  const n=crit+high+med;
  console.log("ℹ️ 미보고 마찰 "+n+"건 (critical "+crit+"·high "+high+"·medium "+med+") — \x27하네스 피드백 분석해줘\x27로 보고 권장");
}
'
}

# ── Snippet 3: cursor 전진 (harness-feedback §7) ──
cursor_advance() {
  local n; n=$(grep -c '' .harness-friction.jsonl 2>/dev/null || echo 0)
  node -e 'const fs=require("fs");fs.writeFileSync(".harness-feedback-cursor",JSON.stringify({processedLines:parseInt(process.argv[1],10)||0,lastReportedAt:"2026-06-17T00:00:00Z"})+"\n")' "$n"
}

# ── Snippet 2: post-cursor 추출 (harness-feedback §1) ──
post_cursor() {
  local p=0
  [ -f .harness-feedback-cursor ] && p=$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(".harness-feedback-cursor","utf8")).processedLines||0)}catch{console.log(0)}')
  tail -n +$((p+1)) .harness-friction.jsonl 2>/dev/null
}

# ── Snippet 4: fingerprint 수집 (harness-feedback §5, gh JSON stdin) ──
fp_collect() {
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let a=[];try{a=JSON.parse(s)}catch{process.exit(0)}for(const it of a){const m=(it.body||"").match(/harness-friction:fp=([^\s]+)\s*-->/);if(m)console.log(m[1]+" #"+it.number)}})'
}

echo "═══ 피드백 보고 트리거 스니펫 픽스처 ═══"

# T1: jsonl 부재 → 트리거 무출력
rm -f .harness-friction.jsonl .harness-feedback-cursor
[ -z "$(trigger_eval)" ] && pass "T1 jsonl 부재 → 무트리거" || fail "T1"

# T2: critical 1건 → 트리거
printf '{"event":"debugger-escalation","severity":"critical"}\n' > .harness-friction.jsonl
trigger_eval | grep -q "미보고 마찰 1건" && pass "T2 critical≥1 → 트리거" || fail "T2: $(trigger_eval)"

# T3: high 1건만 → 무트리거 (보고 기준 미달)
printf '{"event":"e2e-fail","severity":"high"}\n' > .harness-friction.jsonl
[ -z "$(trigger_eval)" ] && pass "T3 high 1건 → 무트리거" || fail "T3: $(trigger_eval)"

# T4: high 2건(다른 event) → 트리거 (high≥2)
printf '{"event":"e2e-fail","severity":"high"}\n{"event":"implementer-retry","severity":"high"}\n' > .harness-friction.jsonl
trigger_eval | grep -q "미보고 마찰 2건" && pass "T4 high≥2 누적 → 트리거" || fail "T4: $(trigger_eval)"

# T5: 동일 event 2건 → 트리거 (동일 event≥2, 교차세션 가정)
printf '{"event":"review-fix","severity":"medium"}\n{"event":"review-fix","severity":"medium"}\n' > .harness-friction.jsonl
trigger_eval | grep -q "미보고 마찰 2건" && pass "T5 동일 event≥2 → 트리거" || fail "T5: $(trigger_eval)"

# T6: infra-track-entry·session-incomplete 제외
printf '{"event":"infra-track-entry","severity":"low"}\n{"event":"session-incomplete","severity":"low"}\n{"event":"e2e-fail","severity":"high"}\n' > .harness-friction.jsonl
[ -z "$(trigger_eval)" ] && pass "T6 감사마커 제외(high 1건만 남아 무트리거)" || fail "T6: $(trigger_eval)"

# T7: cursor 전진 후 미보고 0 → 무트리거 (nagware 방지)
printf '{"event":"debugger-escalation","severity":"critical"}\n' > .harness-friction.jsonl
cursor_advance
[ -z "$(trigger_eval)" ] && pass "T7 보고 후 cursor 전진 → 무트리거" || fail "T7: $(trigger_eval)"
node -e 'const c=JSON.parse(require("fs").readFileSync(".harness-feedback-cursor","utf8"));process.exit(c.processedLines===1?0:1)' && pass "T7b cursor.processedLines=1" || fail "T7b"

# T8: cursor 전진 후 새 critical 1건 추가 → 다시 트리거
printf '{"event":"user-escalation","severity":"critical"}\n' >> .harness-friction.jsonl
trigger_eval | grep -q "미보고 마찰 1건" && pass "T8 cursor 이후 신규 → 재트리거(누적 아님)" || fail "T8: $(trigger_eval)"

# T9: post-cursor 추출 = cursor 이후 줄만
[ "$(post_cursor | grep -c '')" = "1" ] && post_cursor | grep -q user-escalation && pass "T9 post-cursor 추출 정확" || fail "T9: $(post_cursor)"

# T10: cursor 부재 → 전체 평가
rm -f .harness-feedback-cursor
printf '{"event":"debugger-escalation","severity":"critical"}\n' > .harness-friction.jsonl
trigger_eval | grep -q "미보고 마찰 1건" && pass "T10 cursor 부재 → 전체 미보고 평가" || fail "T10"

# T11: 깨진 줄 스킵 (분석) + 물리 줄 수 포함 (cursor)
printf '{"event":"e2e-fail","severity":"high"}\nNOT_JSON\n{"event":"implementer-retry","severity":"high"}\n' > .harness-friction.jsonl
trigger_eval | grep -q "미보고 마찰 2건" && pass "T11 깨진 줄 스킵, high≥2 유지" || fail "T11: $(trigger_eval)"
cursor_advance; node -e 'const c=JSON.parse(require("fs").readFileSync(".harness-feedback-cursor","utf8"));process.exit(c.processedLines===3?0:1)' && pass "T11b 물리 줄 수=3(깨진 줄 포함)" || fail "T11b"

# T12: fingerprint 수집 (gh JSON mock)
echo '[{"number":42,"body":"...\n<!-- harness-friction:fp=event:e2e-fail -->\n..."},{"number":7,"body":"no fp"}]' | fp_collect | grep -q "event:e2e-fail #42" && pass "T12 fingerprint 추출" || fail "T12: $(echo "[]" | fp_collect)"

echo ""; echo "═══ 판정 ═══"
[ $FAILS -eq 0 ] && echo "✅ 전체 통과 — 트리거·cursor·post-cursor·fingerprint 정상" || { echo "❌ $FAILS건 실패"; exit 1; }
