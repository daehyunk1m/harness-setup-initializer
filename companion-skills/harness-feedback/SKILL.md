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

§ 1에서 읽은 `.harness-friction.jsonl`을 **줄 단위**로 파싱한다. 각 줄은 하나의 JSON 객체이며, 다음 필드를 가진다:

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

추출한 이벤트를 분석하여 보고 대상 패턴을 식별한다:

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
```

### detail escape (md 테이블 안전)

이벤트 목록 테이블의 셀에 `detail`(및 다른 필드) 값을 넣을 때, 마크다운 테이블이 깨지지 않도록 escape한다:

- 파이프 `|` → `\|`
- 줄바꿈(LF/CR) → 공백 한 칸

(오케스트레이터가 § 6.1 소독으로 1차 정리하지만, 소비 측에서도 방어적으로 escape한다.)

---

## 6. 사용자 확인

생성한 Issue 초안을 사용자에게 보여준다:

```
📋 Issue 초안 ({N}건):

1. [Friction] {이벤트}: {요약}
   심각도: {level} | 발생: {count}회

2. ...

이대로 GitHub Issue를 생성할까요? (y/수정사항 입력/n)
```

- `y` → § 7 실행
- 수정 요청 → 초안 수정 후 다시 확인
- `n` → "Issue 생성을 취소합니다." 출력 후 종료

---

## 7. Issue 생성

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

---

## 제약 사항

- 마찰 로그의 기존 이벤트를 수정/삭제하지 않는다
- Issue 생성 전 반드시 사용자 확인을 받는다
- 동일한 패턴의 Issue가 이미 존재하는지는 확인하지 않는다 (중복은 수동 관리)
