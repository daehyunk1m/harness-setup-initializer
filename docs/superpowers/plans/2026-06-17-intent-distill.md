# Intent Distill — Phase 2a Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 제품 의도 원장(`.harness-intent.jsonl`)을 `@feature` E2E 실구조와 대조해 커버리지 갭을 `docs/INTENT_BACKLOG.md` 영속 백로그로 동기화하는 `intent-distill` 컴패니언 스킬을 추가한다.

**Architecture:** 하네스 스킬 소스(SKILL.md·템플릿·사양 markdown + bash) 편집이지 런타임 코드 작성이 아니다. 테스트 사이클은 grep 검증 + 골든 픽스처 회귀(`test/run-fixtures.sh`) + 섹션/계약 정합성 검사. harness-feedback 파이프라인을 미러링하되 **마찰의 이벤트-스트림 모델이 아니라 영속-백로그 모델**(상태 파일 없음, 백로그 문서가 durable 상태, 커버리지는 derive). 멀티모델 자문(codex/gemini) 반영.

**Tech Stack:** Markdown 스킬/템플릿/사양, bash, JSON Lines(읽기), markdown 백로그 문서. 검증: `grep`, `bash test/run-fixtures.sh`.

## Global Constraints

스펙(`docs/superpowers/specs/2026-06-17-intent-distill-design.md`)의 전역 요구 — 모든 태스크에 암묵 적용:

- **스코프**: E2E 커버리지 백로그 only. PRD 방향·양방향 바인딩·미검증 명세 = Phase 2b(건드리지 않음).
- **별도 lean 스킬**: harness-feedback과 통합하지 않는다(`--source` 금지). friction 스킬 불변.
- **백로그 = 영속 `docs/INTENT_BACKLOG.md`** (manifest `data`). 키 = 의도 `ts`. 머지(덮어쓰기 아님) — 사용자 `priority/비고`·waiver 보존. idempotent.
- **커버리지 = derive + 증거 + 5-상태**: `covered / partial / missing / ambiguous / invalid-feature`. **feature-범위**로만 E2E 읽음(전체 아님). 증거(스펙 경로·테스트 타이틀·사유) 필수. stored flag 신뢰 금지.
- **상태 파일 없음** (cursor 없음). 세션종료 nudge = 세션-로컬 카운트.
- **gh = 항목별 옵트인**. 백로그 sync는 gh-무관. 이슈 repo = **대상 프로젝트 현재 repo**(harness-setup repo 아님 — `--repo` 하드코딩 금지).
- **`encoded` = 비권위 capture-time 스냅샷** — distill 미갱신. Phase 1 문구 교정.
- **이스케이프**: statement를 백로그/이슈에 넣을 때 `|`→`\|`, 개행→공백, `-->`/`<!--` 무력화, @mention 무력화.
- **Phase 1 원장 스키마 불변** (읽기 전용). **신규 프로필 필드 0**.
- **버전**: `1.24.0` → `1.25.0` (MINOR).
- **E2E 미옵트인 시**: "판정 보류" — 모든 의도를 missing으로 오판 금지.

## File Structure

**생성:**
- `skills/intent-distill/SKILL.md` — distill 엔진(파이프라인·5-상태·머지·이스케이프·옵트인 gh).
- `skills/harness-scaffold/templates/INTENT_BACKLOG.md` — 빈 백로그 doc 템플릿(data).

**수정:**
- `skills/harness-scaffold/SKILL.md` — 생성순서 17-f·§5.12.x·§10.1 22-f·manifest·§7 능력 게이팅.
- `skills/harness-scaffold/templates/INTENT_LEDGER.md` — encoded 문구 교정.
- `skills/harness-scaffold/templates/rules/session-routine.md` — encoded 문구 교정 + 세션종료 nudge.
- `skills/harness-cleanup/SKILL.md` — 격주 B1에 INTENT_BACKLOG 검토.
- `docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md` — Phase 1 spec encoded 문구 교정.
- `.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json` — 스킬 목록 + 버전.
- `README.md` · `skills/harness-setup/references/project-context.md` — 버전.
- `.tracking/CHANGELOG.md` · `HANDOFF.md` · `TODO.md`.

---

### Task 1: INTENT_BACKLOG.md 템플릿 + scaffold 생성 규칙

**Files:**
- Create: `skills/harness-scaffold/templates/INTENT_BACKLOG.md`
- Modify: `skills/harness-scaffold/SKILL.md` (생성순서 ~line 225 `17-e` 다음; §5.12 끝; §10.1 line 1542 `22-e` 다음)

**Interfaces:**
- Produces: 영속 백로그 문서 구조(키=ts, 열린 백로그 표 + waiver 표). Task 2(distill)가 이 구조를 읽고 머지한다 — 컬럼명이 Task 2 머지 규칙과 일치해야 한다.

- [ ] **Step 1: 백로그 템플릿 생성**

`skills/harness-scaffold/templates/INTENT_BACKLOG.md`:

````markdown
# 의도 커버리지 백로그

> `intent-distill`이 `.harness-intent.jsonl` ↔ `@feature` E2E를 대조해 동기화하는 영속 백로그다.
> 커버된 의도는 제거되고, 미커버 갭만 남는다. 사용자가 추가한 `priority/비고`·waiver는 보존된다.
> "의도 정리" / "커버리지 분석"으로 동기화한다.

## 열린 백로그

| key(ts) | feature | surface | kind | statement | state | evidence | priority/비고 |
|---------|---------|---------|------|-----------|-------|----------|---------------|
<!-- intent-distill이 미커버 의도(missing/partial/ambiguous/invalid-feature)를 여기에 동기화한다. key=의도 ts. priority/비고 열은 사용자 소유(머지 보존). -->

## waiver (재추가 안 함)

| key(ts) | statement | 사유 |
|---------|-----------|------|
<!-- "안 함"으로 판정한 의도를 사용자가 여기에 옮기면 distill이 열린 백로그에 재추가하지 않는다. -->
````

- [ ] **Step 2: 생성 순서에 17-f 추가**

`skills/harness-scaffold/SKILL.md`에서 `17-e. .harness-intent.jsonl ...` 줄 다음, `18. package.json` 앞에 삽입:
```
17-f. docs/INTENT_BACKLOG.md (의도 커버리지 백로그 — intent-distill 동기화 대상, data 카테고리; 빈 백로그로 생성 — § 5.12.5)
```

- [ ] **Step 3: §5.12.5 생성 규칙 추가**

`### 5.12.4 .harness-intent.jsonl 생성 규칙` 블록 다음(§5.13 앞)에 추가:

````markdown
### 5.12.5 docs/INTENT_BACKLOG.md 생성 규칙

- 이 스킬의 `templates/INTENT_BACKLOG.md`를 그대로 복사하여 **빈 백로그**로 생성한다 (플레이스홀더 없음).
- `intent-distill` 스킬이 `.harness-intent.jsonl` ↔ `@feature` E2E 커버리지를 대조해 이 문서를 머지-싱크한다(미커버 갭 추가 / 커버됨 제거 / 사용자 주석·waiver 보존).
- manifest category는 **`data`**다 (§ 5.13·§ 10.1) — 런타임 축적, 해시 드리프트 검사 제외, 업그레이드 시 덮어쓰지 않음(TECH_DEBT.md와 동일 취급).
- intent-distill 미실행 시 빈 채로 남는다(무해). E2E 미옵트인 프로젝트에선 distill이 "판정 보류"라 백로그가 비어 있다.
````

- [ ] **Step 4: §10.1 분류표에 22-f 추가**

`| 22-e | \`.harness-intent.jsonl\` | data | ... |` 줄(line 1542) 다음에:
```
| 22-f | `docs/INTENT_BACKLOG.md` | data | 의도 커버리지 백로그(intent-distill 동기화). 런타임 축적, 해시 드리프트 제외, 사용자 주석·waiver 보존 — TECH_DEBT.md와 동일 취급 |
```

- [ ] **Step 5: §5.13 manifest data 목록 갱신**

`§5.13`의 data 파일 목록 행(`.harness-intent.jsonl`을 추가했던 `files.{path}.category` 줄)에서 data 파일 열거에 `·docs/INTENT_BACKLOG.md` 추가:
```bash
grep -n 'data 파일(`feature_list.json`' skills/harness-scaffold/SKILL.md
```
그 줄의 괄호 목록 끝(`·.harness-intent.jsonl`) 다음에 `·docs/INTENT_BACKLOG.md`를 추가한다.

- [ ] **Step 6: 검증**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
F=skills/harness-scaffold/SKILL.md
test -f skills/harness-scaffold/templates/INTENT_BACKLOG.md && echo "TEMPLATE OK"
grep -c '{{' skills/harness-scaffold/templates/INTENT_BACKLOG.md          # expect 0
grep -q '열린 백로그' skills/harness-scaffold/templates/INTENT_BACKLOG.md && grep -q 'waiver' skills/harness-scaffold/templates/INTENT_BACKLOG.md && echo "SECTIONS OK"
grep -q '17-f. docs/INTENT_BACKLOG.md' "$F" && echo "GENORDER OK"
grep -q '### 5.12.5 docs/INTENT_BACKLOG.md' "$F" && echo "RULE OK"
grep -q '22-f' "$F" && echo "CAT OK"
grep -q 'docs/INTENT_BACKLOG.md' <(grep 'data 파일' "$F") && echo "MANIFEST OK"
```
Expected: `TEMPLATE OK` / `0` / `SECTIONS OK` / `GENORDER OK` / `RULE OK` / `CAT OK` / `MANIFEST OK`.

- [ ] **Step 7: 커밋**

```bash
git add skills/harness-scaffold/templates/INTENT_BACKLOG.md skills/harness-scaffold/SKILL.md
git commit -m "$(cat <<'EOF'
feat(templates): INTENT_BACKLOG.md 백로그 doc + scaffold 생성 규칙 (이슈 #15 Phase 2a)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: intent-distill 스킬

**Files:**
- Create: `skills/intent-distill/SKILL.md`

**Interfaces:**
- Consumes: Task 1의 INTENT_BACKLOG.md 구조(열린 백로그 표 컬럼 `key/feature/surface/kind/statement/state/evidence/priority|비고`, waiver 표 `key/statement/사유`). Phase 1 `.harness-intent.jsonl` 스키마(`{ts,session,kind,surface,feature,statement,encoded}`).
- Produces: distill 엔진의 행동 정본. Task 3(능력 게이팅)·Task 4(nudge/B1)가 이 스킬을 가리킨다.

- [ ] **Step 1: 스킬 파일 생성 (전체 내용)**

`skills/intent-distill/SKILL.md`:

````markdown
---
name: intent-distill
description: "제품 의도 원장(.harness-intent.jsonl)을 @feature E2E 실구조와 대조해 커버리지 갭을 docs/INTENT_BACKLOG.md 영속 백로그로 동기화하는 스킬. '의도 정리', '의도 증류', '커버리지 분석', 'intent distill' 등을 요청할 때 사용한다."
allowed-tools: Bash(cat *) Bash(echo *) Bash(ls *) Bash(grep *)
---

# Intent Distill Skill

제품 의도(`.harness-intent.jsonl`, Phase 1 수집)를 읽어 각 의도가 `@feature` E2E로 커버되는지 **실구조에서 파생**하고, 미커버 갭을 `docs/INTENT_BACKLOG.md`(영속 백로그)에 **머지-싱크**한다. harness-feedback의 자매이나, 마찰의 이벤트-스트림 모델이 아니라 **지속 백로그 모델**이다 — 상태 파일(cursor) 없음, 백로그 문서가 durable 상태, 커버리지는 매 실행 derive(저장 flag 신뢰 안 함).

이 스킬은 **대상 프로젝트의 제품 의도**를 다룬다(하네스 자체가 아님) — gh 이슈는 현재 프로젝트 repo에 생성한다.

## 1. 의도 원장 읽기

```!
if [ -f .harness-intent.jsonl ]; then cat .harness-intent.jsonl; else echo "INTENT_LOG_NOT_FOUND"; fi
```

`INTENT_LOG_NOT_FOUND`이면 "`.harness-intent.jsonl`이 없습니다. 하네스가 셋업된 프로젝트에서 실행하세요." 출력 후 **종료**.

### 1.1 관용 파싱

- 빈 줄 무시. 각 줄을 JSON 파싱하되 **실패한 줄은 건너뛰고** 개수를 세어 리포트(§6)에 보고한다.
- 필드: `{ts, session, kind(intended|unintended), surface, feature, statement, encoded}`. **cursor 없음 — 전체 의도를 분석한다.** `encoded`는 **비권위라 읽지 않는다**(커버리지는 §4에서 실구조 파생).
- 유효 의도 0건이면 "기록된 의도가 없습니다." 출력 후 종료.

## 2. 백로그 읽기

```!
if [ -f docs/INTENT_BACKLOG.md ]; then cat docs/INTENT_BACKLOG.md; else echo "BACKLOG_NOT_FOUND"; fi
```

부재 시 빈 백로그(열린 백로그 0행, waiver 0행)로 시작한다. `## 열린 백로그` 표(키=ts)와 `## waiver` 표(키=ts)를 파싱하고, 사용자 `priority/비고` 열·waiver 항목을 **보존 대상**으로 기억한다.

## 3. E2E 계층 확인

```!
if [ -d e2e/specs ] && ls e2e/specs/*.e2e.ts >/dev/null 2>&1; then echo "E2E_PRESENT"; else echo "E2E_ABSENT"; fi
```

`E2E_ABSENT`이면: "이 프로젝트는 E2E 계층이 없어 커버리지 판정을 보류합니다(E2E 도입 후 재실행). 적재된 의도 {N}건은 'E2E 도입 후 판정' 상태입니다." 출력 후 **종료**한다 — 모든 의도를 missing으로 오판하지 않는다.

## 4. 커버리지 파생 (feature-범위, 증거 필수)

각 의도(intended+unintended)에 대해 5-상태를 산출한다:

1. `feature`가 `""`이거나 `feature_list.json`에 없으면 → **`invalid-feature`** (증거: 사유 "feature 미지정/미존재"). 다음 의도로.
2. 해당 feature의 E2E 스펙을 **feature-범위로만** 찾는다(전체 E2E를 올리지 않는다):
   ```bash
   grep -rl "@feature:{feature}" e2e/specs/ 2>/dev/null
   ```
   매칭 스펙이 없으면 → **`missing`** (증거: feature_list 항목 + "@feature:{feature} 스펙 없음").
3. 매칭 스펙이 있으면 그 스펙 **파일만** 읽어 `statement`와 의미상 일치하는 시나리오(test/it 타이틀)를 판단:
   - 일치 시나리오 있음 → **`covered`** (증거: 스펙 경로 + 테스트 타이틀).
   - feature E2E는 있으나 이 statement 미커버 → **`partial`** (증거: 스펙 경로 + 미커버 요지).
   - 모호(statement 모호 / 매칭 불확실) → **`ambiguous`** (증거: 사유).

**모든 판정에 증거 필수** — 증거 없는 `covered`/`missing` 단정 금지.

(최적화: 백로그에 `covered` 증거로 이미 기록됐고 그 스펙 파일이 안 바뀐 의도는 재판정 스킵 가능.)

## 5. 백로그 머지 (idempotent)

키 = 의도 `ts`. 각 의도:
- `covered` → 열린 백로그에 있으면 **제거**(해소).
- `missing` / `partial` / `ambiguous` / `invalid-feature` → 열린 백로그에 **없으면 추가**, 있으면 `state`/`evidence` **갱신**.
- **waiver 섹션에 키가 있으면 스킵**(재추가 안 함).

기존 행의 사용자 `priority/비고` 열은 키 매칭으로 **보존**(덮어쓰기 아닌 머지). waiver 섹션은 distill이 수정하지 않는다. → 같은 입력 = 같은 백로그(재실행 동일).

statement를 표 셀에 넣을 때 **§7 이스케이프**를 적용한다.

## 6. 리포트

```
📊 의도 커버리지 동기화:
  신규 갭 {N}건 · 해소 {M}건 · triage(ambiguous/invalid) {K}건
  (파싱 실패 줄: {P}개)

열린 백로그 (상위):
  - [missing]  F007  someday 제외 — @feature:F007 스펙 없음
  - [partial]  F007  각 날만 집계 — e2e/specs/F007-progress.e2e.ts (이 시나리오 미커버)
  ...
```

머지 결과를 `docs/INTENT_BACKLOG.md`에 쓰고 변경을 보고한다.

## 7. statement 이스케이프 (백로그·이슈 안전)

백로그 표 셀·gh 이슈 body에 statement를 넣을 때(Phase 1 ≤200 소독은 JSON 안전일 뿐):
- 파이프 `|` → `\|`, 줄바꿈(LF/CR) → 공백 한 칸.
- HTML 주석 delimiter 무력화: statement 내 `-->`·`<!--` → 공백 치환(fingerprint 주석 교란 차단).
- @mention 무력화: `@` → 코드 스팬(`` `@name` ``) 래핑 또는 zero-width 삽입.

## 8. gh 이슈 (항목별 옵트인)

백로그 항목을 사용자가 명시적으로 지시할 때만 생성한다(자동 생성 안 함):

```
백로그 항목을 GitHub Issue로 만들까요? (항목 번호 입력 / n=안 함)
```

선택 항목에 대해 — **현재 프로젝트 repo**에 생성(`--repo` 하드코딩 안 함):

```bash
gh issue create --label intent-gap \
  --title "[Intent] {feature}: {요약}" \
  --body "{§7로 이스케이프된 body}

<!-- intent-gap:fp={feature}:{ts} -->"
```

생성 직전 동일 `fp`의 열린 이슈를 조회해 있으면 "⚠️ 유사 열린 Issue #N — 중복일 수 있음" 힌트(하드 스킵 아님 — 사용자 판단). `gh` 미설치/실패 → 이슈만 스킵하고 백로그 sync는 정상 진행한다.

## 제약 사항

- 의도 원장(`.harness-intent.jsonl`)을 수정/삭제하지 않는다(읽기 전용; `encoded` 미갱신 — 비권위).
- 커버리지는 매 실행 실구조에서 파생한다(저장된 flag 신뢰 안 함). **증거 필수.**
- 백로그는 **머지**(덮어쓰기 아님) — 사용자 주석·waiver 보존. 키=`ts`라 재실행이 idempotent.
- gh 이슈는 **항목별 옵트인** + 사용자 확인. 백로그 sync는 gh-무관. 이슈 repo = 현재 프로젝트.
- harness-feedback(마찰 채널)과 **별개**다 — 통합하지 않는다.
````

- [ ] **Step 2: 검증**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
F=skills/intent-distill/SKILL.md
test -f "$F" && echo "SKILL OK"
grep -q '^name: intent-distill' "$F" && grep -q 'allowed-tools:' "$F" && echo "FRONTMATTER OK"
for s in '## 1. 의도 원장' '## 2. 백로그 읽기' '## 3. E2E 계층' '## 4. 커버리지 파생' '## 5. 백로그 머지' '## 7. statement 이스케이프' '## 8. gh 이슈' '## 제약 사항'; do grep -q "$s" "$F" || echo "MISSING: $s"; done; echo "SECTIONS checked"
for st in covered partial missing ambiguous invalid-feature; do grep -q "$st" "$F" || echo "MISSING state: $st"; done; echo "STATES checked"
grep -q 'cursor 없음' "$F" && grep -q '증거 필수' "$F" && grep -q 'idempotent' "$F" && echo "MODEL OK"
grep -q 'repo 하드코딩 안 함\|--repo 하드코딩' "$F" || grep -q '현재 프로젝트 repo' "$F" && echo "GH-REPO OK"
grep -c '{{' "$F"   # expect 0 (no placeholders)
```
Expected: `SKILL OK` / `FRONTMATTER OK` / `SECTIONS checked`(no MISSING) / `STATES checked`(no MISSING) / `MODEL OK` / `GH-REPO OK` / `0`.

- [ ] **Step 3: 커밋**

```bash
git add skills/intent-distill/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): intent-distill 스킬 — 커버리지 파생 + 백로그 머지-싱크 (이슈 #15 Phase 2a)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Phase 1 encoded 문구 교정 + §7 능력 게이팅

**Files:**
- Modify: `skills/harness-scaffold/templates/INTENT_LEDGER.md` (line 4-5, 41, 45, 52)
- Modify: `skills/harness-scaffold/templates/rules/session-routine.md` (line 428, 444)
- Modify: `skills/harness-scaffold/SKILL.md` (§7 능력 줄 ~line 1415)
- Modify: `docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md` (Phase 1 spec encoded 문구)

**Interfaces:**
- Consumes: Task 2(intent-distill 존재 — 증류가 이제 배선됨).
- Produces: encoded가 비권위임을 명시(codex 계약 지적 해소), 능력 카탈로그가 증류를 광고.

- [ ] **Step 1: INTENT_LEDGER.md encoded 문구 교정**

(a) line 41 교체:
```
| `encoded` | `{prd, e2e, test}` 승격 상태 슬롯 — **비권위 capture-time 스냅샷**(Phase 1 항상 all-false). 커버리지의 권위는 `docs/INTENT_BACKLOG.md`(intent-distill이 실구조에서 파생) — distill은 이 필드를 갱신하지 않는다 |
```

(b) line 45 `## 증류 (Phase 2 — 예정, 미배선)` → `## 증류 (intent-distill)` 로 교체하고, 그 섹션 본문에서 "미배선/예정" 표현을 "intent-distill 스킬이 수행한다"로 바꾼다.

(c) line 52 교체:
```
> 커버리지는 intent-distill이 `.harness-intent.jsonl` ↔ `@feature` E2E를 대조해 `docs/INTENT_BACKLOG.md`에 동기화한다("의도 정리"). `encoded`는 비권위 스냅샷이라 갱신하지 않는다.
```

(d) line 5(헤더) "추후 ... 증류한다(Phase 2 — 미배선)" → "intent-distill이 `docs/INTENT_BACKLOG.md`로 증류한다('의도 정리')".

- [ ] **Step 2: session-routine § 의도 로그 encoded 문구 교정**

(a) line 444 교체:
```
| `encoded` | `{"prd":false,"e2e":false,"test":false}` — **항상 all-false, 비권위**(커버리지는 intent-distill이 INTENT_BACKLOG.md로 파생; distill 미갱신) |
```

(b) line 428의 "추후 PRD·E2E 근거로 증류한다(Phase 2 — 미배선)" → "intent-distill이 `@feature` E2E와 대조해 `docs/INTENT_BACKLOG.md`로 증류한다('의도 정리')".

- [ ] **Step 3: §7 능력 게이팅 — 의도 적재 줄 갱신 + 의도 증류 줄 추가**

`skills/harness-scaffold/SKILL.md`의 의도 적재 줄(line 1415) 교체:
```
- 의도 적재 → 세션 종료 시 제품 의도(intended/unintended)가 `.harness-intent.jsonl`에 적재 (상세: .claude/rules/session-routine.md § 의도 로그) — always-on
```
그 다음 줄에 의도 증류 능력 줄 추가:
```
- 의도 증류 → "의도 정리"로 `.harness-intent.jsonl`을 @feature E2E와 대조해 `docs/INTENT_BACKLOG.md` 커버리지 백로그 동기화 (상세: intent-distill 스킬 — 플러그인 번들)
```
그리고 §7 렌더링 규칙의 "하네스 정리 · 피드백 분석 줄"(플러그인 번들 항상 호출) 설명에 intent-distill도 포함되도록 "의도 증류" 줄을 같은 부류(번들 스킬 항상 렌더)로 추가한다 — 해당 규칙 줄을 찾아 `harness-cleanup·harness-feedback` 열거에 `·intent-distill` 추가.

- [ ] **Step 4: Phase 1 spec encoded 문구 교정**

`docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md`에서 "Phase 2 distill이 encoded 자리만 갱신"/"Phase 2 distill이 채움" 류 문구를 찾아, "encoded는 비권위 capture-time 스냅샷 — Phase 2a(intent-distill)는 커버리지를 실구조에서 파생하며 encoded를 갱신하지 않는다(derived-live, 멀티모델 자문 반영)"로 교정한다:
```bash
grep -n 'encoded' docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md | grep -i '갱신\|채움\|Phase 2'
```
출력된 각 줄을 위 취지로 교정(D4 결정 표 + §12 비-스코프 포함).

- [ ] **Step 5: 검증**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
grep -q '비권위 capture-time 스냅샷' skills/harness-scaffold/templates/INTENT_LEDGER.md && echo "LEDGER OK"
grep -q '항상 all-false, 비권위' skills/harness-scaffold/templates/rules/session-routine.md && echo "ROUTINE OK"
grep -q '의도 증류 → .의도 정리' skills/harness-scaffold/SKILL.md && echo "CAP OK"
# 미배선 광고 잔존 없음 (의도 적재 줄이 더 이상 '증류 미배선'을 말하지 않음)
grep '의도 적재 →' skills/harness-scaffold/SKILL.md | grep -q '미배선' && echo "WARN: still says 미배선" || echo "NO-STALE OK"
grep -iq 'derived-live\|비권위' docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md && echo "SPEC OK"
```
Expected: `LEDGER OK` / `ROUTINE OK` / `CAP OK` / `NO-STALE OK` / `SPEC OK`.

- [ ] **Step 6: 커밋**

```bash
git add skills/harness-scaffold/templates/INTENT_LEDGER.md skills/harness-scaffold/templates/rules/session-routine.md skills/harness-scaffold/SKILL.md docs/superpowers/specs/2026-06-17-intent-ledger-capture-design.md
git commit -m "$(cat <<'EOF'
fix(skill): encoded 비권위 명시 + Phase 4 능력 카탈로그에 의도 증류 (이슈 #15 Phase 2a)

멀티모델 자문(codex) 계약 지적 반영 — derived-live라 encoded 미갱신.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: 세션종료 nudge + harness-cleanup B1 편입

**Files:**
- Modify: `skills/harness-scaffold/templates/rules/session-routine.md` (§ 세션 종료 — Task 3 § 의도 로그와 별개 위치)
- Modify: `skills/harness-cleanup/SKILL.md` (§ B1, line ~97; B2 line ~104 앞)

**Interfaces:**
- Consumes: Task 2(intent-distill), Task 1(INTENT_BACKLOG.md).
- Produces: distill의 운영 트리거(세션종료 경량 nudge + 격주 리뷰).

- [ ] **Step 1: 세션종료 경량 nudge 추가**

`session-routine.md § 세션 종료` 코드블록에서 `4.2 의도 적재` 줄 다음에 nudge 한 줄 삽입(세션-로컬 카운트 — 상태 파일 없음):
```
4.3 의도 증류 nudge — 이번 세션에 의도를 1건 이상 적재했으면 한 줄 제안만: "이번 세션 의도 {N}건 적재 — '의도 정리'로 INTENT_BACKLOG 동기화 권장"(자동 실행 안 함; 무거운 sync는 온디맨드/격주 B1)
```
(`4.5 피드백 보고 트리거`는 그대로 둔다.)

- [ ] **Step 2: harness-cleanup 격주 B1에 INTENT_BACKLOG 검토 추가**

`skills/harness-cleanup/SKILL.md`의 `### B2. 승격 대기 큐 점검` 헤딩 **바로 앞**에 한 줄(또는 B1 말미)을 추가:
```
- `docs/INTENT_BACKLOG.md` 열린 백로그 검토 — 미커버 의도(missing/partial)를 `feature_list.json` 작업/E2E 스펙으로 승격 제안, invalid-feature/ambiguous는 triage. (동기화: "의도 정리" — intent-distill)
```

- [ ] **Step 3: 검증**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
grep -q '4.3 의도 증류 nudge' skills/harness-scaffold/templates/rules/session-routine.md && echo "NUDGE OK"
grep -q 'INTENT_BACKLOG.md 열린 백로그 검토' skills/harness-cleanup/SKILL.md && echo "B1 OK"
# nudge가 상태 파일을 도입하지 않음 (세션-로컬)
grep '4.3 의도 증류 nudge' skills/harness-scaffold/templates/rules/session-routine.md | grep -q 'cursor\|상태 파일' && echo "WARN: state file" || echo "NO-STATE OK"
```
Expected: `NUDGE OK` / `B1 OK` / `NO-STATE OK`.

- [ ] **Step 4: 커밋**

```bash
git add skills/harness-scaffold/templates/rules/session-routine.md skills/harness-cleanup/SKILL.md
git commit -m "$(cat <<'EOF'
feat(skill): 세션종료 의도 증류 nudge + 격주 B1 INTENT_BACKLOG 검토 (이슈 #15 Phase 2a)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 정합성·회귀 검증 게이트 (커밋 없음)

**Files:** (없음 — 검증 전용)

**Interfaces:**
- Consumes: Task 1–4. Produces: 릴리스 전 게이트.

- [ ] **Step 1: 골든 픽스처 회귀**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
bash test/run-fixtures.sh; echo "EXIT=$?"
```
Expected: 모든 픽스처 통과, `EXIT=0`(structural-test 미변경).

- [ ] **Step 2: harness-feedback 불변 + 원장 스키마 불변 (통합 안 함, 읽기 전용)**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
git diff main...HEAD --stat -- skills/harness-feedback/ | tail -1   # expect: (변경 없음 — 빈 출력)
[ -z "$(git diff main...HEAD -- skills/harness-feedback/)" ] && echo "FEEDBACK UNCHANGED OK" || echo "WARN: feedback changed"
# 원장 스키마(필드) 불변 — INTENT_LEDGER.md 7필드 유지(문구만 교정)
grep -oE '"(ts|session|kind|surface|feature|statement|encoded)"' skills/harness-scaffold/templates/INTENT_LEDGER.md | sort -u | tr '\n' ' '; echo
```
Expected: `FEEDBACK UNCHANGED OK` / 7필드 `"encoded" "feature" "kind" "session" "statement" "surface" "ts"`.

- [ ] **Step 3: 신규 플레이스홀더 0 + 신규 프로필 필드 0**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
git diff main...HEAD -- skills/ | grep '^+' | grep -oE '\{\{[A-Z_]+\}\}' | sort -u   # expect: (빈 출력)
git diff main...HEAD -- skills/harness-scaffold/SKILL.md | grep -E '^\+' | grep -iE 'profile\.[a-z]|## 4\. 프로필 입력' | grep -ivE 'INTENT|의도|intent\b' || echo "(프로필 스키마 변경 없음 — OK)"
```
Expected: 첫 블록 빈 출력, 둘째 블록 `(프로필 스키마 변경 없음 — OK)`.

- [ ] **Step 4: 스킬 구조 정합 (5-상태 ↔ 백로그 ↔ scaffold)**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
# distill의 5-상태가 모두 명시
for st in covered partial missing ambiguous invalid-feature; do grep -q "$st" skills/intent-distill/SKILL.md || echo "MISSING: $st"; done; echo "states checked"
# 백로그 템플릿 컬럼 ↔ distill 머지 키(ts) 정합
grep -q 'key(ts)' skills/harness-scaffold/templates/INTENT_BACKLOG.md && grep -q '키 = 의도 `ts`' skills/intent-distill/SKILL.md && echo "KEY OK"
```
Expected: `states checked`(no MISSING) / `KEY OK`. (4개 게이트 통과 후 Task 6. 커밋 없음.)

---

### Task 6: 스킬 등록 + 버전 1.25.0 + 트래킹

**Files:**
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`, `skills/harness-setup/references/project-context.md`
- Modify: `.tracking/CHANGELOG.md`, `.tracking/HANDOFF.md`, `.tracking/TODO.md`

**Interfaces:**
- Consumes: Task 1–5 완료. Produces: 1.25.0 릴리스 메타 + 스킬 등록 + 트래킹.

- [ ] **Step 1: 스킬 목록에 intent-distill 등록**

`.claude-plugin/plugin.json`의 `description`에서 스킬 괄호 목록 `(harness-setup, harness-scaffold, harness-cleanup, harness-feedback, multi-model-consult)`에 `, intent-distill`을 추가한다. `.claude-plugin/marketplace.json`을 Read해 동일한 스킬 나열이 있으면 거기에도 `intent-distill`을 추가한다(없으면 변경 없음 — 보고).
> plugin.json엔 별도 `skills` 배열이 없다(skills/ 자동 디스커버리). 등록 = description 목록 갱신 + `skills/intent-distill/SKILL.md` 존재(Task 2).

- [ ] **Step 2: 버전 1.24.0 → 1.25.0**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
grep -rln '1\.24\.0' --include='*.json' --include='*.md' . | grep -v node_modules | grep -v '/CHANGELOG.md' | grep -v 'docs/superpowers/'
```
출력된 현재-버전 참조(plugin.json `version`, README 버전 줄, project-context 헤더)를 `1.25.0`으로 바꾼다. 과거 이력(CHANGELOG 기존 항목, 릴리스 히스토리 테이블, install.sh 전환 안내, docs/superpowers spec/plan)은 보존(Phase 1 Task 7 판단 기준 동일).

검증:
```bash
grep -m1 '"version"' .claude-plugin/plugin.json   # expect 1.25.0
```

- [ ] **Step 3: CHANGELOG 항목**

`.tracking/CHANGELOG.md` 최상단에:
```markdown
## [1.25.0] — 2026-06-17

### Added
- **Intent Distill — Phase 2a (이슈 #15)**: 제품 의도 원장의 E2E 커버리지 증류. `intent-distill` 컴패니언 스킬 — `.harness-intent.jsonl`을 `@feature` E2E와 대조해 5-상태(covered/partial/missing/ambiguous/invalid-feature) 커버리지를 **실구조에서 파생**(증거 필수)하고 `docs/INTENT_BACKLOG.md` 영속 백로그에 머지-싱크(idempotent, 사용자 주석·waiver 보존).
  - 세션종료 경량 nudge(세션-로컬) + 격주 B1 리뷰 편입. gh 이슈는 항목별 옵트인(현재 repo).
  - 멀티모델 자문(codex/gemini) 반영: 영속 백로그 모델(이산 gh 이슈 기각), 별도 lean 스킬(통합 기각), 상태파일 제거.

### Changed
- `encoded` 필드는 비권위 capture-time 스냅샷으로 명시(intent-distill 미갱신 — derived-live). INTENT_LEDGER.md·session-routine·Phase 1 spec 문구 교정.
- Phase 4 능력 카탈로그에 "의도 증류" 추가, "의도 적재" 줄에서 "증류 미배선" 제거.
```

- [ ] **Step 4: project-context + HANDOFF + TODO**

- `project-context.md`: 버전 히스토리에 `1.25.0 — Intent Distill Phase 2a(이슈 #15)` + § 설계 결정에 "intent-distill은 영속 백로그(INTENT_BACKLOG.md) 모델·derived 커버리지·별도 스킬 — 멀티모델 자문 반영. encoded 비권위."
- `HANDOFF.md`: "Intent Distill Phase 2a 완료(이슈 #15). Phase 2b(PRD substrate) 미착수." 반영.
- `TODO.md`: Phase 2a 항목(TODO-103~107 중 distill 관련) 완료 체크, Phase 2b 잔여 명확화(PRD substrate·prd_section_ref·양방향 바인딩·미검증 명세).

- [ ] **Step 5: 검증 + 커밋**

```bash
cd /Users/daehyun/Desktop/side-project/harness-setup-initializer
grep -q 'intent-distill' .claude-plugin/plugin.json && echo "REGISTER OK"
grep -q '1.25.0' .tracking/CHANGELOG.md && grep -q '1.25.0' skills/harness-setup/references/project-context.md && echo "VERSION OK"
```
Expected: `REGISTER OK` / `VERSION OK`.

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json README.md \
        skills/harness-setup/references/project-context.md \
        .tracking/CHANGELOG.md .tracking/HANDOFF.md .tracking/TODO.md
git commit -m "$(cat <<'EOF'
chore(skill,tracking): intent-distill 등록 + 1.25.0 범프 + 트래킹 (이슈 #15 Phase 2a)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

> **git tag**: `v1.25.0`는 main 병합 시점에 생성(이 플랜에서 태그 안 함).

---

## Self-Review (작성자 체크 결과)

**1. Spec coverage** (spec §4 구성요소 → 태스크):
- §4.1 intent-distill 스킬 → Task 2. ✓
- §4.2 INTENT_BACKLOG.md → Task 1. ✓
- §4.3 5-상태 판정 → Task 2 §4(스킬 본문). ✓
- §4.4 scaffold(생성순서·능력 게이팅) → Task 1(생성) + Task 3(능력). ✓
- §4.5 세션종료 nudge → Task 4. ✓
- §4.6 격주 B1 → Task 4. ✓
- §4.7 encoded 교정 → Task 3. ✓
- §4.8 등록+버전 → Task 6. ✓
- §7 머지 규칙 → Task 2 §5. ✓ · §8 이스케이프 → Task 2 §7. ✓
- §11 버전/마이그레이션 → Task 6. §12 검증 → 각 Task verify + Task 5 게이트. §13 수용기준 → 분산 커버.

**2. Placeholder scan**: TBD/TODO 없음. 모든 편집 전체 내용 제시(SKILL.md·백로그 템플릿 전문 포함).

**3. Type/구조 일관성**: 백로그 컬럼(`key/feature/surface/kind/statement/state/evidence/priority|비고`)이 Task 1 템플릿 ↔ Task 2 머지 규칙에서 동일. 5-상태 문자열이 spec §6 ↔ Task 2 ↔ Task 5 게이트에서 동일. 키=`ts` 일관. 버전 1.25.0 일관.
