---
name: harness-feedback
description: "하네스 마찰 로그(.harness-friction.jsonl)를 분석하여 반복 패턴을 식별하고, harness-setup 리포에 개선 Issue를 생성하는 스킬. '피드백 분석', '하네스 피드백', 'harness feedback', '마찰 분석' 등을 요청할 때 사용한다."
allowed-tools: Bash(cat *) Bash(echo *)
---

# Harness Feedback Skill

## 1. 마찰 로그 읽기

마찰 이벤트는 프로젝트 루트의 `.harness-friction.jsonl`(append-only, 한 줄 = 1 이벤트)에 자동 기록된다. 이 파일을 입력으로 읽는다.

```!
if [ -f .harness-friction.jsonl ]; then
  cat .harness-friction.jsonl
else
  echo "FRICTION_LOG_NOT_FOUND"
fi
```

위 출력이 `FRICTION_LOG_NOT_FOUND`이면:
"`.harness-friction.jsonl`이 없습니다. 하네스가 셋업된 프로젝트에서 실행하세요." 출력 후 **즉시 종료**한다.

### 1.1 보고 위치 cursor

`.harness-feedback-cursor`(있으면)를 읽어 **이미 처리한 물리 줄 수(`processedLines`) 이후**만 분석 대상으로 삼는다. cursor가 없으면 전체를 분석한다(첫 실행). 이렇게 하면 이미 보고/무시한 마찰을 재분석하지 않아 닫힌 Issue 재보고 루프가 차단된다.

```bash
PROCESSED=0
[ -f .harness-feedback-cursor ] && PROCESSED=$(node -e 'try{console.log(JSON.parse(require("fs").readFileSync(".harness-feedback-cursor","utf8")).processedLines||0)}catch{console.log(0)}')
echo "PROCESSED_LINES: $PROCESSED"
tail -n +$((PROCESSED + 1)) .harness-friction.jsonl   # cursor 이후 물리 줄만 (분석 입력)
```

---

## 2. 환경 정보 수집

```bash
echo "=== ENV ==="
echo "node: $(node -v 2>/dev/null || echo 'N/A')"
echo "npm: $(npm -v 2>/dev/null || echo 'N/A')"
cat package.json 2>/dev/null | grep '"name"' | head -1
cat .harness-manifest.json 2>/dev/null | grep -E '"version"|"generatedAt"'
echo "=== END ENV ==="
```

이 정보는 § 5에서 Issue body에 포함한다.

---

## 3. 이벤트 파싱

**cursor 이후(§1.1) 이벤트만** 파싱한다. § 1에서 읽은 `.harness-friction.jsonl`을 **줄 단위**로 파싱한다. 각 줄은 하나의 JSON 객체이며, 다음 필드를 가진다:

```json
{"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-a3f9","event":"implementer-retry","severity":"high","feature":"F-12","detail":"타입 에러 3회 반복"}
```

| 필드 | 의미 |
|------|------|
| `ts` | 이벤트 발생 시각 (ISO8601 UTC) |
| `session` | 세션 고유 ID — 형식 `{ISO 시각}-{4자 난수}` (예: `2026-06-16T09-12-03Z-a3f9`) |
| `event` | 이벤트 유형 enum |
| `severity` | `low` \| `medium` \| `high` \| `critical` |
| `feature` | feature ID 또는 `""` |
| `detail` | 소독된 원인 한 줄 (≤50자) |

### 관용 파싱 (깨진 줄 격리)

- 빈 줄은 무시한다.
- 각 줄을 JSON으로 파싱하되, **파싱에 실패한 줄은 건너뛴다.** 깨진 한 줄이 전체 분석을 죽이지 않는다.
- 건너뛴 줄의 개수를 세어 두고, § 4 분석 결과와 § 6 사용자 확인 시 함께 보고한다(예: "파싱 실패로 건너뛴 줄: {M}개").
- 파싱에 성공한 줄들만 § 4 패턴 분석의 입력으로 삼는다.

파싱에 성공한 이벤트가 0건이면(파일은 존재하나 유효한 줄이 없음):
"기록된 이벤트가 없습니다." 출력 후 **즉시 종료**한다.

---

## 4. 패턴 분석

**cursor 이후(§1.1) 이벤트만** 분석한다. 추출한 이벤트를 분석하여 보고 대상 패턴을 식별한다:

### 보고 기준

| 조건 | 분류 |
|------|------|
| `critical` 심각도 이벤트 1회 이상 | 즉시 보고 |
| 동일 이벤트 유형 2회 이상 | 반복 패턴 |
| `high` 심각도 이벤트 2회 이상 | 반복 패턴 |

### 패턴 그룹핑

보고 기준에 해당하는 이벤트를 이벤트 유형별로 그룹핑한다. 각 그룹이 하나의 Issue가 된다.

보고 대상 패턴이 없으면:
"보고 기준을 충족하는 패턴이 없습니다. critical 이벤트 1회 이상, 또는 동일 event 2회 이상이 기준입니다." (§ 3에서 파싱 실패로 건너뛴 줄이 있으면 "파싱 실패로 건너뛴 줄: {M}개"도 함께 보고) 출력 후 **즉시 종료**한다.

---

## 5. Issue 초안 생성

각 패턴 그룹에 대해 Issue 초안을 작성한다.

### Issue 형식

```markdown
**Title**: [Friction] {event}: {패턴 요약}

**Labels**: friction

**Body**:
## 마찰 패턴

- **이벤트**: {event}
- **발생 횟수**: {N}회
- **심각도**: {최고 severity}

## 이벤트 목록

| ts | session | feature | detail |
|------|---------|---------|--------|
{해당 이벤트 행들 — 각 줄의 ts·session·feature·detail 값}

## 환경 정보

- Node: {버전}
- 프로젝트: {package.json name}
- 하네스 버전: {manifest version}
- 생성일: {manifest generatedAt}

## 재현 맥락

{이벤트의 detail 필드에서 공통 맥락 추출. 추출이 어려우면 "각 이벤트의 detail 필드를 참고하세요." 기재}

<!-- harness-friction:fp=event:{event} -->
```

### detail escape (md 테이블 안전)

이벤트 목록 테이블의 셀에 `detail`(및 다른 필드) 값을 넣을 때, 마크다운 테이블이 깨지지 않도록 escape한다:

- 파이프 `|` → `\|`
- 줄바꿈(LF/CR) → 공백 한 칸

(오케스트레이터가 § 6.1 소독으로 1차 정리하지만, 소비 측에서도 방어적으로 escape한다.)

### 5.1 중복 힌트 (열린 Issue fingerprint 대조 — 백스톱)

cursor가 주 방어이나, cursor 분실·동시 실행 대비로 초안 표시 전 **열린 friction Issue의 fingerprint**를 조회해 같은 패턴이 이미 열려 있으면 §6 확인에 "⚠️ 유사 열린 Issue #N — 중복일 수 있음"을 함께 보여준다(하드 스킵 아님 — 사용자 판단). gh 실패 시 힌트 스킵 + 경고(degradation, 기존 동작 유지).

```bash
gh issue list --repo daehyunk1m/harness-setup-initializer --label friction --state open --json number,body 2>/dev/null \
| node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let a=[];try{a=JSON.parse(s)}catch{process.exit(0)}for(const it of a){const m=(it.body||"").match(/harness-friction:fp=([^\s]+)\s*-->/);if(m)console.log(m[1]+" #"+it.number)}})'
```

초안 패턴의 fp(`event:{event}`)가 위 목록에 있으면 해당 Issue 번호를 힌트로 표시한다.

---

## 6. 사용자 확인

생성한 Issue 초안을 사용자에게 보여준다:

```
📋 Issue 초안 ({N}건):

1. [Friction] {이벤트}: {요약}
   심각도: {level} | 발생: {count}회

2. ...

이대로 GitHub Issue를 생성할까요? (y=생성 / d=무시(보고 불필요로 표시) / 수정사항 입력 / n=취소)
```

- `y` → § 7 실행 (생성 + cursor 전진)
- `d` → 생성 안 함 + **cursor만 전진**(검토했고 보고 불필요 — 재제안 침묵). "cursor를 현재까지 전진시켰습니다(보고 없음)." 출력
- 수정 요청 → 초안 수정 후 재확인
- `n` → "Issue 생성을 취소합니다 (cursor 미전진 — 다음에 재포착)." 출력 후 종료

---

## 7. Issue 생성

`gh issue create` **직전** §5.1 fingerprint를 재조회해 같은 fp의 열린 Issue가 새로 생겼으면 사용자에게 알리고 생성 보류.

사용자가 승인한 각 Issue에 대해:

```bash
gh issue create \
  --repo daehyunk1m/harness-setup-initializer \
  --label friction \
  --title "{title}" \
  --body "{body}"
```

생성 결과를 보고한다:

```
✅ Issue 생성 완료 ({N}건):
  - #123: [Friction] setup-mismatch: 아키텍처 유형 잘못 감지
  - #124: [Friction] implementer-retry: 반복 구현 실패
```

`gh` CLI가 설치되지 않았거나 인증되지 않은 경우:
"gh CLI가 필요합니다. `gh auth login`으로 인증 후 다시 시도하세요." 출력 후 종료.

### 7.1 cursor 전진 (생성 또는 무시 후)

생성(`y`) 또는 무시(`d`) 후, cursor를 현재 jsonl 물리 줄 수로 전진시킨다. 취소(`n`)면 전진하지 않는다.

```bash
LINES=$(grep -c '' .harness-friction.jsonl 2>/dev/null || echo 0)
node -e 'const fs=require("fs");fs.writeFileSync(".harness-feedback-cursor",JSON.stringify({processedLines:parseInt(process.argv[1],10)||0,lastReportedAt:process.argv[2]})+"\n")' "$LINES" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "✅ cursor 전진: processedLines=$LINES"
```

---

## 제약 사항

- 마찰 로그의 기존 이벤트를 수정/삭제하지 않는다
- Issue 생성 전 반드시 사용자 확인을 받는다
- 보고 위치를 `.harness-feedback-cursor`로 추적해 재분석을 막는다(닫힌 Issue 재보고는 cursor 이후 재발 시에만). 열린 friction Issue fingerprint를 백스톱 힌트로 대조한다(하드 dedup 아님 — 최종 판단은 사용자).
