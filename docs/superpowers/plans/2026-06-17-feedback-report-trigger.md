# 피드백 보고 트리거 구현 계획 (이슈 #14)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 세션 종료 시 cursor 이후 미보고 마찰을 평가해 harness-feedback 실행을 한 줄로 권장하는 무-훅 트리거를 추가하고, `.harness-feedback-cursor` 북마크로 dead-letter·nagware·닫힌이슈 재분석 루프를 동시에 차단한다.

**Architecture:** 신규 `data` 파일 `.harness-feedback-cursor`(1줄 JSON, `processedLines`=처리한 물리 줄 수)가 단일 상태원이다. session-routine 세션 종료가 cursor 이후 이벤트를 보고 기준으로 평가해 제안만 출력(gh 무호출). harness-feedback은 cursor 이후만 분석하고 보고/무시 시 cursor를 EOF로 전진시킨다. 월간 운영 사이클은 보조 net. 실행 로직(트리거 평가·cursor 전진·post-cursor 추출·fingerprint)은 골든 픽스처로 회귀 검증한다.

**Tech Stack:** Markdown 스킬 스펙(session-routine.md·harness-feedback/SKILL.md·harness-scaffold/SKILL.md) + 임베디드 node/bash 스니펫 + 골든 픽스처(bash) + gh CLI.

**설계 정본:** `docs/superpowers/specs/2026-06-17-feedback-report-trigger-design.md`

---

## 파일 구조 (생성/수정)

| 파일 | 책임 | 작업 |
|------|------|------|
| `test/feedback-cursor-fixtures.sh` | 실행 스니펫 4종 회귀 검증 (스킬 자체 검증, footprint 0) | **생성** |
| `templates/rules/session-routine.md` | 세션 종료 트리거 단계 (Snippet 1) | 수정 (§ 세션 종료) |
| `companion-skills/harness-feedback/SKILL.md` | cursor 읽기/분석/전진 + fingerprint 힌트 + §6 3분기 | 수정 (§1·§4·§5·§6·§7·제약) |
| `harness-scaffold/SKILL.md` | cursor 생성 규칙 + manifest data + 생성순서 + 운영사이클 + 버전 | 수정 (§5.12.2·§5.13·§10.1·생성순서·§5.1.1 CLAUDE.md·버전) |
| `companion-skills/harness-cleanup/SKILL.md` | 월간 루틴 보조 net 라인 | 수정 (§5 월간 루틴) |
| `SKILL.md` | 프로필 스키마 version 1.21.0→1.22.0 | 수정 |
| `references/versioning-policy.md` | 1.22.0 행 | 수정 |
| `.tracking/CHANGELOG.md`·`project-context.md`·`HANDOFF.md`·`TODO.md` | 릴리스 기록 | 수정 |

**상태 계약 (모든 태스크 공통):** `.harness-feedback-cursor` = 단일 JSON 라인 `{"processedLines": N, "lastReportedAt": "<ISO|null>"}`. `processedLines` = `grep -c '' .harness-friction.jsonl`(물리 줄 수 = 이벤트 수, append-only이므로 안전; 마지막 줄에 개행 없어도 정확 — `wc -l`보다 견고). cursor 부재 = `processedLines:0`(전체 미보고).

---

## Task 1: 실행 스니펫 4종 + 골든 픽스처 (TDD)

**Files:**
- Create: `test/feedback-cursor-fixtures.sh`

> 이 픽스처가 스니펫 4종의 **정본 로직**이다. Task 2·3이 동일 스니펫을 스펙 문서에 임베드한다(동기 유지).

- [ ] **Step 1: 픽스처 파일 생성 (실패 케이스 먼저)**

`test/feedback-cursor-fixtures.sh`를 아래 내용으로 생성한다. 4개 스니펫(트리거 평가·post-cursor 추출·cursor 전진·fingerprint 수집)을 함수로 정의하고 시나리오로 검증한다.

```bash
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
  console.log("ℹ️ 미보고 마찰 "+n+"건 (critical "+crit+"·high "+high+"·medium "+med+") — '하네스 피드백 분석해줘'로 보고 권장");
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

# T6: infra-track-entry·session-incomplete 제외 (판별력 — SKIP 없으면 동일event≥2로 트리거됨)
printf '{"event":"infra-track-entry","severity":"low"}\n{"event":"infra-track-entry","severity":"low"}\n{"event":"session-incomplete","severity":"low"}\n{"event":"session-incomplete","severity":"low"}\n' > .harness-friction.jsonl
[ -z "$(trigger_eval)" ] && pass "T6 감사마커 제외(infra×2·incomplete×2 — SKIP 없으면 동일event≥2, 제외로 무트리거)" || fail "T6: $(trigger_eval)"

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
```

- [ ] **Step 2: 실행 (구현 전엔 의미 없음 — 픽스처가 곧 구현이므로 바로 통과 기대)**

Run: `bash test/feedback-cursor-fixtures.sh`
Expected: `✅ 전체 통과` (T1~T12). 실패하면 해당 스니펫 로직을 수정한다.

> 이 태스크는 스니펫 로직 자체를 픽스처로 확정하는 단계다. 픽스처가 통과해야 Task 2·3의 임베드 대상이 확정된다.

- [ ] **Step 3: 커밋**

```bash
git add test/feedback-cursor-fixtures.sh
git commit -m "test(test): 피드백 보고 트리거 스니펫 골든 픽스처 (이슈 #14)"
```

---

## Task 2: session-routine 세션 종료 트리거 배선

**Files:**
- Modify: `templates/rules/session-routine.md` (§ 세션 종료, 현재 304-318)

- [ ] **Step 1: § 세션 종료 절차에 트리거 단계 삽입**

§ 세션 종료의 코드블록(`1. {{VALIDATE_COMMAND}}` ~ `5. 미커밋 변경...`)에서, **4번(session-incomplete 기록)과 5번(커밋) 사이**에 새 단계 `4.5`를 추가한다 (session-incomplete append 이후지만 트리거가 그것을 제외하므로 무관). 코드블록 직후에 트리거 산문 + Snippet 1을 추가한다.

코드블록 `4.` 다음에 삽입:
```
4.5 피드백 보고 트리거 — cursor 이후 미보고 마찰을 평가해 충족 시 한 줄 제안 (§ 피드백 보고 트리거)
```

§ 세션 종료 코드블록 닫는 ``` 뒤, `---` 앞에 새 산문 블록 추가:

````markdown
### 피드백 보고 트리거

세션 종료 시 `.harness-friction.jsonl`의 **cursor(`.harness-feedback-cursor`) 이후** 이벤트를 보고 기준으로 평가해, 충족하면 **한 줄 제안만** 출력한다(자동 실행·gh 호출 없음 — 무-훅·승인 없이 실행 금지 원칙). 보고하면 cursor가 전진하므로 다음 세션엔 재제안되지 않는다(nagware 방지). `infra-track-entry`(감사 마커)·`session-incomplete`(루틴 기록)는 마찰 카운트·기준에서 제외한다. jsonl 부재 시 스킵, cursor 부재 시 전체를 미보고로 평가한다.

기준은 harness-feedback 보고 기준과 **동일**(`critical≥1 OR 동일 event≥2 OR high≥2`)하되 **cursor 이후 누적 윈도우**에 적용한다 — 트리거↔보고 정합(제안=반드시 보고 가능). 누적 윈도우라 단일 세션 dedup 제약(같은 feature+event 1회)을 넘어 교차세션·다feature로 기준 달성이 가능하다.

```sh
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
  console.log("ℹ️ 미보고 마찰 "+n+"건 (critical "+crit+"·high "+high+"·medium "+med+") — \x27하네스 피드백 분석해줘\x27로 보고 권장 (글로벌 컴패니언)");
}
'
```
````

> **임베드 검증**: 위 ```sh 스니펫은 `test/feedback-cursor-fixtures.sh`의 `trigger_eval()`와 로직 동일해야 한다(한글 메시지는 픽스처에선 유니코드 이스케이프, 문서에선 원문 — 로직 동치).

- [ ] **Step 2: § 마찰 로그 규칙에 cursor 1줄 추가**

§ 마찰 로그(현재 ~389)의 **규칙** 목록 끝에 추가:
```
- 보고 상태는 `.harness-feedback-cursor`(별도 파일, append-only jsonl 미변경)가 추적한다 — harness-feedback이 보고/무시 시 처리한 물리 줄 수까지 전진시키고, 세션 종료 트리거(§ 피드백 보고 트리거)가 그 이후만 평가한다.
```

- [ ] **Step 3: 검증 — 문서 스니펫이 픽스처와 동치인지 + 렌더**

Run:
```bash
grep -q "피드백 보고 트리거" templates/rules/session-routine.md && echo "✅ 섹션 존재"
grep -q "harness-feedback-cursor" templates/rules/session-routine.md && echo "✅ cursor 언급"
bash test/feedback-cursor-fixtures.sh | tail -1
```
Expected: `✅ 섹션 존재` / `✅ cursor 언급` / `✅ 전체 통과`

- [ ] **Step 4: 커밋**

```bash
git add templates/rules/session-routine.md
git commit -m "feat(templates): session-routine 세션 종료 피드백 보고 트리거 (이슈 #14)"
```

---

## Task 3: harness-feedback cursor 배선

**Files:**
- Modify: `companion-skills/harness-feedback/SKILL.md` (§1·§4·§5·§6·§7·제약)

- [ ] **Step 1: §1 마찰 로그 읽기 — cursor 인지 추가**

§1의 `!` 블록 다음(line ~22 "즉시 종료한다." 뒤)에 cursor 읽기 산문 + ```bash 추가:

````markdown
### 1.1 보고 위치 cursor

`.harness-feedback-cursor`(있으면)를 읽어 **이미 처리한 물리 줄 수(`processedLines`) 이후**만 분석 대상으로 삼는다. cursor가 없으면 전체를 분석한다(첫 실행). 이렇게 하면 이미 보고/무시한 마찰을 재분석하지 않아 닫힌 Issue 재보고 루프가 차단된다.

```bash
PROCESSED=0
[ -f .harness-feedback-cursor ] && PROCESSED=$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(".harness-feedback-cursor","utf8")).processedLines||0)}catch{console.log(0)}')
echo "PROCESSED_LINES: $PROCESSED"
tail -n +$((PROCESSED + 1)) .harness-friction.jsonl   # cursor 이후 물리 줄만 (분석 입력)
```
````

- [ ] **Step 2: §3/§4 분석 범위를 cursor 이후로 한정**

§3 이벤트 파싱 도입부, §4 패턴 분석 도입부에 1줄씩 명시: "**cursor 이후(§1.1) 이벤트만** 파싱/분석한다." (기준 자체는 불변: critical≥1 / 동일 event≥2 / high≥2.)

- [ ] **Step 3: §5 Issue body에 fingerprint + §5 직전 dedup 힌트**

§5 Issue 형식의 Body 템플릿 끝(`## 재현 맥락` 뒤)에 fingerprint 주석 추가:
```markdown
<!-- harness-friction:fp=event:{event} -->
```

§5와 §6 사이에 dedup 힌트 산문 + ```bash 추가:

````markdown
### 5.1 중복 힌트 (열린 Issue fingerprint 대조 — 백스톱)

cursor가 주 방어이나, cursor 분실·동시 실행 대비로 초안 표시 전 **열린 friction Issue의 fingerprint**를 조회해 같은 패턴이 이미 열려 있으면 §6 확인에 "⚠️ 유사 열린 Issue #N — 중복일 수 있음"을 함께 보여준다(하드 스킵 아님 — 사용자 판단). gh 실패 시 힌트 스킵 + 경고(degradation, 기존 동작 유지).

```bash
gh issue list --repo daehyunk1m/harness-setup-initializer --label friction --state open --json number,body 2>/dev/null \
| node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let a=[];try{a=JSON.parse(s)}catch{process.exit(0)}for(const it of a){const m=(it.body||"").match(/harness-friction:fp=([^\s]+)\s*-->/);if(m)console.log(m[1]+" #"+it.number)}})'
```

초안 패턴의 fp(`event:{event}`)가 위 목록에 있으면 해당 Issue 번호를 힌트로 표시한다.
````

- [ ] **Step 4: §6 확인을 3분기로 확장**

§6의 확인 프롬프트를 `(y/수정/n)` → 3분기로 교체:
```
이대로 GitHub Issue를 생성할까요? (y=생성 / d=무시(보고 불필요로 표시) / 수정사항 입력 / n=취소)
```
- `y` → §7 실행 (생성 + cursor 전진)
- `d` → 생성 안 함 + **cursor만 전진**(검토했고 보고 불필요 — 재제안 침묵). "cursor를 현재까지 전진시켰습니다(보고 없음)." 출력
- 수정 요청 → 초안 수정 후 재확인
- `n` → "Issue 생성을 취소합니다 (cursor 미전진 — 다음에 재포착)." 출력 후 종료

- [ ] **Step 5: §7 생성에 race 재조회 + cursor 전진**

§7 도입부에 race 가드 1줄: "`gh issue create` **직전** §5.1 fingerprint를 재조회해 같은 fp의 열린 Issue가 새로 생겼으면 사용자에게 알리고 생성 보류." §7 `gh issue create` 블록 다음에 cursor 전진 ```bash 추가:

````markdown
### 7.1 cursor 전진 (생성 또는 무시 후)

생성(`y`) 또는 무시(`d`) 후, cursor를 현재 jsonl 물리 줄 수로 전진시킨다. 취소(`n`)면 전진하지 않는다.

```bash
LINES=$(grep -c '' .harness-friction.jsonl 2>/dev/null || echo 0)
node -e 'const fs=require("fs");fs.writeFileSync(".harness-feedback-cursor",JSON.stringify({processedLines:parseInt(process.argv[1],10)||0,lastReportedAt:process.argv[2]})+"\n")' "$LINES" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "✅ cursor 전진: processedLines=$LINES"
```
````

- [ ] **Step 6: § 제약 사항 갱신**

`- 동일한 패턴의 Issue가 이미 존재하는지는 확인하지 않는다 (중복은 수동 관리)` 행을 교체:
```
- 보고 위치를 `.harness-feedback-cursor`로 추적해 재분석을 막는다(닫힌 Issue 재보고는 cursor 이후 재발 시에만). 열린 friction Issue fingerprint를 백스톱 힌트로 대조한다(하드 dedup 아님 — 최종 판단은 사용자).
```

- [ ] **Step 7: 검증**

Run:
```bash
grep -q "harness-feedback-cursor" companion-skills/harness-feedback/SKILL.md && echo "✅ cursor 배선"
grep -q "harness-friction:fp=event" companion-skills/harness-feedback/SKILL.md && echo "✅ fingerprint"
grep -q "d=무시" companion-skills/harness-feedback/SKILL.md && echo "✅ 3분기"
bash test/feedback-cursor-fixtures.sh | tail -1
```
Expected: 4줄 모두 ✅

- [ ] **Step 8: 커밋**

```bash
git add companion-skills/harness-feedback/SKILL.md
git commit -m "feat(skill): harness-feedback cursor 추적 + fingerprint dedup + 3분기 확인 (이슈 #14)"
```

---

## Task 4: harness-scaffold cursor 생성 규칙

**Files:**
- Modify: `harness-scaffold/SKILL.md` (§5.12.2 신설·생성순서·§5.13/§10.1 manifest)

- [ ] **Step 1: §5.12.2 cursor 생성 규칙 신설**

§5.12.1(.harness-friction.jsonl 생성, ~811-820) **직후**에 추가:

````markdown
### 5.12.2 .harness-feedback-cursor 생성 규칙

피드백 보고 트리거(session-routine § 피드백 보고 트리거)와 harness-feedback의 **보고 위치 북마크**다. jsonl과 별개 파일이라 append-only를 보존한다.

- 스캐폴드 시 빈 초기값으로 생성한다: `echo '{"processedLines": 0, "lastReportedAt": null}' > .harness-feedback-cursor`
- manifest category는 **`data`**다 (§ 5.13·§ 10.1) — feature_list.json·.harness-friction.jsonl과 동일 취급(해시 드리프트 검사 제외, 업그레이드 시 덮어쓰지 않음).
- 부재 시 graceful: 트리거·harness-feedback이 `processedLines:0`(전체 미보고)로 동작하므로, 기존 하네스(업그레이드)는 첫 보고 시 자동 생성된다(마이그레이션 불필요). 업그레이드 직후 첫 세션 종료엔 누적 백로그가 "미보고 N건"으로 노출된다(의도 — 이슈 #14의 목적).
````

- [ ] **Step 2: 생성 순서에 단계 추가**

생성 순서 `17-b. .harness-friction.jsonl` (line ~222) 다음에:
```
17-c. .harness-feedback-cursor (빈 보고 위치 북마크 — 프로젝트 루트, data 카테고리 — § 5.12.2)
```

- [ ] **Step 3: §10.1 파일별 분류 표에 행 추가**

§10.1 파일 카테고리 표(~1447-1476)의 `.harness-friction.jsonl`(#22-b) 다음에:
```
| 22-c | `.harness-feedback-cursor` | data | 보고 위치 북마크(프로젝트 루트). 런타임 데이터, 해시 드리프트 검사 제외 — feature_list.json·.harness-friction.jsonl과 동일 취급 |
```

- [ ] **Step 4: §5.13 manifest 스키마 예시에 cursor 반영 (선택, files{} 주석)**

§5.13 manifest 생성 규칙에서 data 파일 목록을 언급하는 곳에 `.harness-feedback-cursor`를 포함(`.harness-friction.jsonl`과 동급). 예시 JSON 변경 불필요(data는 해시 제외).

- [ ] **Step 5: 검증**

Run:
```bash
grep -q "5.12.2" harness-scaffold/SKILL.md && grep -q "harness-feedback-cursor" harness-scaffold/SKILL.md && echo "✅ 생성 규칙"
grep -q "17-c" harness-scaffold/SKILL.md && echo "✅ 생성 순서"
grep -q "22-c" harness-scaffold/SKILL.md && echo "✅ manifest 분류"
```
Expected: 3줄 ✅

- [ ] **Step 6: 커밋**

```bash
git add harness-scaffold/SKILL.md
git commit -m "feat(skill): .harness-feedback-cursor 생성 규칙 + manifest data 분류 (이슈 #14)"
```

---

## Task 5: 운영 사이클 월간 보조 net

**Files:**
- Modify: `companion-skills/harness-cleanup/SKILL.md` (§5 월간 루틴)
- Modify: `harness-scaffold/SKILL.md` (§5.1.1 CLAUDE.md 생성 — 운영 사이클 템플릿)

- [ ] **Step 1: harness-cleanup 월간 루틴에 피드백 분석 단계 추가**

`## 5. 월간 루틴 (M)` 섹션(line ~115)의 마지막 M 항목 뒤에 추가:

````markdown
### M4. 피드백 보고 백업 (보조 net)

세션 종료 트리거(session-routine § 피드백 보고 트리거)가 **주 그물망**이고, 월간은 보조다. `.harness-friction.jsonl`에 cursor(`.harness-feedback-cursor`) 이후 미보고 마찰이 남아 있으면(드물게 세션 종료에서 놓친 누적), harness-feedback 실행을 **제안**한다. cursor 기반이라 재실행이 중복 Issue를 만들지 않는다.

> 정직 표기: 월간이 안 돌아도 세션 종료 트리거가 매 세션 미보고를 surface하므로 dead-letter 위험은 낮다. 월간은 belt-and-suspenders.
````

- [ ] **Step 2: 생성 CLAUDE.md 운영 사이클 템플릿에 1줄 (선택)**

harness-scaffold §5.1.1 CLAUDE.md 생성 시 "운영 사이클" 안내에서 월간 항목에 "+ 미보고 마찰 피드백 분석(보조)"을 덧붙이도록 1줄 지시 추가. (Phase 4 보고 line ~1365 운영 안내와 정합.)

- [ ] **Step 3: 검증**

Run:
```bash
grep -q "M4" companion-skills/harness-cleanup/SKILL.md && grep -q "피드백 보고 백업" companion-skills/harness-cleanup/SKILL.md && echo "✅ 월간 보조 net"
```
Expected: ✅

- [ ] **Step 4: 커밋**

```bash
git add companion-skills/harness-cleanup/SKILL.md harness-scaffold/SKILL.md
git commit -m "feat(skill): 운영 사이클 월간에 피드백 보고 보조 net (이슈 #14)"
```

---

## Task 6: 버전 범프 1.21.0 → 1.22.0

**Files:**
- Modify: `SKILL.md` (프로필 출력 스키마 version)
- Modify: `harness-scaffold/SKILL.md` (프로필 입력 스키마 version)
- Modify: `references/versioning-policy.md` (1.22.0 행)

- [ ] **Step 1: 두 SKILL.md version 동기 범프**

각 파일의 프로필 스키마 `"version": "1.21.0",` → `"version": "1.22.0",` (둘 다, 정확히 동일).

- [ ] **Step 2: versioning-policy 1.22.0 행 추가**

`| 1.21.0 릴리스 |` 행 다음에:
```
| 1.22.0 릴리스 | 피드백 보고 트리거(이슈 #14): 신규 data 파일 `.harness-feedback-cursor`(보고 위치 북마크) + session-routine 세션 종료 트리거 + harness-feedback cursor 추적·fingerprint dedup·3분기 확인 + 월간 보조 net. cursor 부재 graceful(마이그레이션 불필요). 신규 플레이스홀더 0. | MINOR | 새 data 파일 + managed 템플릿 행동 추가 — 기존 하네스 호환 |
```

- [ ] **Step 3: 검증**

Run:
```bash
[ "$(grep -c '"version": "1.22.0"' SKILL.md harness-scaffold/SKILL.md | grep -c ':1')" = "2" ] && echo "✅ 양쪽 1.22.0"
grep -rq '"version": "1.21.0"' SKILL.md harness-scaffold/SKILL.md && echo "❌ 잔여 1.21.0" || echo "✅ 잔여 없음"
grep -q "1.22.0 릴리스" references/versioning-policy.md && echo "✅ policy 행"
```
Expected: `✅ 양쪽 1.22.0` / `✅ 잔여 없음` / `✅ policy 행`

- [ ] **Step 4: 커밋**

```bash
git add SKILL.md harness-scaffold/SKILL.md references/versioning-policy.md
git commit -m "chore(skill,refs): 1.22.0 버전 범프 (이슈 #14)"
```

---

## Task 7: 트래킹 업데이트

**Files:**
- Modify: `.tracking/CHANGELOG.md`·`references/project-context.md`·`.tracking/HANDOFF.md`·`.tracking/TODO.md`

- [ ] **Step 1: CHANGELOG [1.22.0] 추가**

`## [1.21.0]` 위에 `## [1.22.0] — 2026-06-17 (피드백 보고 트리거 — 이슈 #14)` 섹션 추가 (Added: cursor 파일·세션 종료 트리거·harness-feedback cursor/fingerprint/3분기·월간 보조 net / 비고: 멀티모델 자문 반영·MINOR·마이그레이션 불필요·골든 픽스처).

- [ ] **Step 2: project-context 버전 히스토리 1.22.0 항목**

`### 1.21.0` 위에 `### 1.22.0 (피드백 보고 트리거 — 이슈 #14)` + 설계 요지(cursor 무상태 결정·자문 3결함 해소·트리거↔보고 정합) 추가.

- [ ] **Step 3: HANDOFF Session 48 + 현재 버전 + 열린 이슈**

Session 48 항목 추가, "현재 버전: 1.22.0", "열린 이슈: 0건(#14 종결)" 갱신. P7(검증 피드백 루프) 행에 1.22.0 추가.

- [ ] **Step 4: TODO-102 완료 처리**

TODO-102(이슈 #14)를 `[x] 완료 (Session 48, 1.22.0)`로 변경 + 해결 요지·검증 근거 기재.

- [ ] **Step 5: 커밋**

```bash
git add .tracking/CHANGELOG.md references/project-context.md .tracking/HANDOFF.md .tracking/TODO.md
git commit -m "docs(tracking): 1.22.0 피드백 보고 트리거 트래킹 (이슈 #14)"
```

---

## Task 8: 최종 검증 + 적대적 리뷰 + 종결

- [ ] **Step 1: 전체 골든 픽스처 회귀**

Run:
```bash
bash test/feedback-cursor-fixtures.sh | tail -1
bash test/run-fixtures.sh | tail -1
bash test/e2e-fixtures.sh | tail -1
```
Expected: 모두 `✅ 전체 통과`

- [ ] **Step 2: 정합성 그렙**

Run:
```bash
grep -rq '"version": "1.21.0"' SKILL.md harness-scaffold/SKILL.md && echo "❌ 버전 잔여" || echo "✅ 버전 동기"
grep -q "feedback-cursor" templates/rules/session-routine.md companion-skills/harness-feedback/SKILL.md harness-scaffold/SKILL.md && echo "✅ 3곳 배선"
```
Expected: `✅ 버전 동기` / cursor 배선 확인

- [ ] **Step 3: (선택) 적대적 리뷰 워크플로**

스니펫 정확성·스펙 정합성·degradation 3관점으로 변경 diff를 적대적 리뷰(이슈 #13에서 사용한 패턴). 확정 발견만 반영.

- [ ] **Step 4: push + 이슈 #14 종결**

```bash
git push origin main
git tag -a v1.22.0 -m "1.22.0 — 피드백 보고 트리거 (이슈 #14)"
git push origin v1.22.0
gh issue close 14 --comment "해소 — v1.22.0. cursor 북마크 기반 무-훅 세션 종료 트리거 + harness-feedback cursor 추적/fingerprint dedup/3분기 확인 + 월간 보조 net. 멀티모델 자문(codex·gemini) 반영."
```

---

## Self-Review (작성자 점검)

**1. Spec coverage**: spec §4.1 cursor→Task4 / §4.2 트리거→Task2 / §4.3 harness-feedback→Task3 / §4.4 월간→Task5 / §4.5 scaffold→Task4 / §6 degradation→Task1 픽스처(T6·T10·T11) / §7 버전→Task6 / §8 검증→Task1·8. **갭 없음.**

**2. Placeholder scan**: `{event}`(fingerprint 치환)·`{{VALIDATE_COMMAND}}`(기존 플레이스홀더)·`{N}`(메시지 카운트)는 정당한 템플릿 변수. TBD/TODO 없음.

**3. Type consistency**: cursor 키 `processedLines`·`lastReportedAt` — Task1(픽스처)·Task3(전진)·Task4(생성)·Task2(읽기) 전부 동일. 트리거 기준 `critical≥1 OR 동일 event≥2 OR high≥2` — spec·Task1·Task2 동일. fingerprint `harness-friction:fp=event:{event}` — Task3 생성·Task1 추출 동일.

---

## 잔존 결정 (실행 중 확인 가능)
- Task5 Step2(생성 CLAUDE.md 운영사이클 1줄)는 선택 — 누락해도 harness-cleanup M4가 정본.
- fingerprint를 `event:{event}`로만 둘지 severity까지 포함할지: 패턴 그룹핑이 event별이므로 `event:{event}`로 충분(spec 일치).
