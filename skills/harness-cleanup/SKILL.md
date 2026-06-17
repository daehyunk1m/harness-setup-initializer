---
name: harness-cleanup
description: "하네스가 셋업된 프로젝트의 엔트로피를 주기적으로 정리하는 스킬. 운영 사이클(주간/격주/월간)의 실행 주체다 — 문서 부식 감지, QUALITY_SCORE 재측정, TECH_DEBT·승격 큐 검토, 문서-실구조 일치 검사, passes 재검증. '하네스 정리', 'harness cleanup', '주간 정리', '월간 점검', '엔트로피 정리' 등을 요청할 때 사용한다."
allowed-tools: Bash(cat *) Bash(echo *) Bash([ *) Bash(test *)
---

# Harness Cleanup Skill

하네스 구성 체크리스트 § 6(엔트로피 관리)과 운영 사이클(§ 6.3)의 실행 주체다.
하네스는 만드는 것이 아니라 운영하는 것이다 — 이 스킬이 그 운영 루프를 담당한다.

## 1. 전제 확인 + 정리 로그 읽기

```!
echo "=== CLEANUP STATE ==="
[ -f .harness-manifest.json ] && echo "MANIFEST=exists" || echo "MANIFEST=missing"
if [ -f docs/CLEANUP_LOG.md ]; then
  echo "--- CLEANUP_LOG ---"
  cat docs/CLEANUP_LOG.md
else
  echo "CLEANUP_LOG=missing"
fi
echo "=== END STATE ==="
```

- `MANIFEST=missing`이면: "하네스가 셋업되지 않은 프로젝트입니다. `/harness-setup`을 먼저 실행하세요." 출력 후 **즉시 종료**한다.
- `CLEANUP_LOG=missing`이면 첫 실행이다 — § 7에서 로그 파일을 생성한다.

---

## 2. 루틴 판별

실행할 루틴을 결정한다. 우선순위:

1. **사용자가 명시한 경우** — "주간 정리", "월간 점검", "전체 점검" 등 요청에 루틴이 명시되면 그것을 따른다
2. **로그 기반 자동 판별** — § 1의 CLEANUP_LOG에서 각 루틴의 마지막 실행일을 찾아 경과 시간으로 판별한다:

| 루틴 | 포함 조건 |
|------|----------|
| 주간 (W) | 마지막 주간 실행 ≥ 7일 전, 또는 기록 없음 |
| 격주 (B) | 마지막 격주 실행 ≥ 14일 전, 또는 기록 없음 |
| 월간 (M) | 마지막 월간 실행 ≥ 30일 전 (기록 없으면 첫 실행에서는 제외 — 사용자가 원하면 포함) |

3. 판별 결과를 사용자에게 제시하고 확인 받은 후 시작한다:

```
🧹 하네스 정리 — 실행할 루틴
- 주간 (W1~W4): 마지막 실행 {N}일 전 → 포함
- 격주 (B1~B2): 마지막 실행 {N}일 전 → 포함
- 월간 (M1~M3): 마지막 실행 {N}일 전 → 제외 (다음 예정: {날짜})

진행할까요? (y / 루틴 조정)
```

---

## 3. 주간 루틴 (W)

### W1. 문서 최신성

`npm run doc:check` 실행 → 오래된(⚠️)/누락(❌) 문서 목록을 수집한다.
오래된 문서는 W2~W4, M1의 결과를 반영해 갱신하면 자연히 해소된다 — 단순히 mtime을 갱신하기 위한 무의미한 수정은 하지 않는다.

### W2. QUALITY_SCORE 재측정

`docs/QUALITY_SCORE.md`의 6개 카테고리를 측정하고 갱신을 제안한다:

| 카테고리 (배점) | 측정 방법 |
|----------------|----------|
| 타입 안전성 (20) | typecheck 통과 여부 + `any` 사용 수 (`grep -rn ": any\|as any" --include="*.ts*" {srcRoot}` ) |
| 테스트 커버리지 (20) | 커버리지 도구가 있으면 실행, 없으면 핵심 경로(서비스/훅) 테스트 파일 존재 비율 |
| 아키텍처 준수 (20) | `npm run lint:arch` 위반 수 — 0건이면 만점 |
| 접근성 (15) | 컴포넌트 샘플링 — 시맨틱 태그, ARIA, 키보드 접근 (백엔드 프로젝트는 API 에러 응답 일관성으로 대체) |
| 성능 (15) | 빌드 성공 + 번들/산출물 크기 추이, 명백한 안티패턴 샘플링 |
| 문서 최신성 (10) | W1 결과 — 경고 0건이면 만점 |

- 점수표의 점수·측정일을 갱신하고, 측정 근거를 "알려진 이슈" 또는 비고에 한 줄씩 남긴다
- **직전 측정 대비 하락한 카테고리**는 보고에서 강조한다

### W3. 코드 엔트로피 스캔

기계적으로 찾을 수 있는 부식 흔적을 수집한다 (발견만 — 처리는 § 6):

- **잔존 산출물**: 소스 옆에 남은 컴파일 결과물 (`.test.ts` 옆 `.test.js`, `.d.ts` 잔재 등 — 빌드 산출물이 소스 트리에 섞인 경우)
- **크기 위반**: 300줄 초과 파일 중 직전 정리 이후 새로 생긴 것
- **금지 패턴 증가**: `any` 사용, 주석 처리된 코드 블록(10줄 이상), stale `TODO`/`FIXME`(작성 후 방치)
- **미사용 의존성 후보**: package.json dependencies 중 소스에서 import되지 않는 것 (확신 없으면 후보로만 보고)

### W4. 검증 상태

`npm run harness:check` 실행 → 구조(①②③)/품질(④⑤) 항목 결과와 단계 판정을 기록한다.

---

## 4. 격주 루틴 (B)

### B1. TECH_DEBT 검토

`docs/TECH_DEBT.md`의 각 항목에 대해:
- **해결됨**: 코드를 확인해 이미 해소된 항목 → "해결됨 ({날짜})" 표시 제안 (행 삭제는 하지 않는다 — 이력 보존)
- **재분류**: 심각도가 변한 항목 (예: 방치로 보통 → 높음) → 이동 제안
- **신규**: W3에서 발견한 엔트로피 중 즉시 수정하지 않는 것 → 새 항목 추가 제안

- `docs/INTENT_BACKLOG.md` 열린 백로그 검토(2차원) — **tested-but-unspecced**(e2e covered·prd missing)는 PRD 작성, **specced-but-untested**(prd covered·e2e missing)는 E2E 스펙 작성으로 승격 제안, invalid-feature/ambiguous는 triage, blocked(substrate 부재)는 보류. (동기화: "의도 정리" — intent-distill)

### B2. 승격 대기 큐 점검

"자동 검사 승격 대기 큐"에서 **횟수 ≥ 2** 항목을 찾아 자동 검사 승격을 제안한다:
- ESLint 규칙으로 표현 가능 → 규칙 스니펫 제시
- import 방향 문제 → structural-test 확장 제시
- 동작 규칙 → 테스트 케이스 제시

승격이 적용되면 큐의 상태를 "승격됨"으로 갱신한다.

---

## 5. 월간 루틴 (M)

### M1. 문서-실구조 일치 (문서 부식)

- **AGENTS.md**: 명시된 모든 경로가 실제 존재하는가, 문서 맵의 링크가 유효한가, "## 명령어"의 명령이 package.json scripts와 일치하는가, 100줄 이내인가
- **ARCHITECTURE.md**: 폴더 목록 vs 실제 디렉토리 — 새 폴더(문서에 없음) / 사라진 폴더(문서에만 있음), 의존성 규칙이 structural-test 설정과 일치하는가
- 불일치는 **문서를 실제에 맞게** 수정 제안한다 (실제 구조가 규칙 위반이면 lint:arch가 잡을 일이므로, 여기서는 문서 쪽을 갱신)

### M2. passes 재검증

`feature_list.json`에서 `passes: true`인 기능에 대해:
- 해당 기능의 테스트가 여전히 존재하고 통과하는지 확인 (전체 테스트는 W4 validate로 이미 실행됨 — 기능↔테스트 매핑 위주로 점검)
- 회귀 발견 시: `passes: false`로 되돌리고 notes에 "회귀 — {사유} ({날짜})" 기록을 제안한다. 복구 작업은 다음 TDD 세션의 회귀 우선 규칙에 위임한다 (이 스킬이 직접 수정하지 않는다)
- 기능 수가 많으면 직전 월간 점검 이후 변경된 파일과 관련된 기능을 우선 점검한다

### M3. 종합 판정

W4의 harness:check 결과와 M1~M2를 종합해 하네스 단계(표준/MVH)를 판정하고, 다음 달까지의 개선 우선순위 1~3개를 제안한다.

### M4. 피드백 보고 백업 (보조 net)

세션 종료 트리거(session-routine § 피드백 보고 트리거)가 **주 그물망**이고, 월간은 보조다. `.harness-friction.jsonl`에 cursor(`.harness-feedback-cursor`) 이후 미보고 마찰이 남아 있으면(드물게 세션 종료에서 놓친 누적), harness-feedback 실행을 **제안**한다. cursor 기반이라 재실행이 중복 Issue를 만들지 않는다.

> 정직 표기: 월간이 안 돌아도 세션 종료 트리거가 매 세션 미보고를 surface하므로 dead-letter 위험은 낮다. 월간은 belt-and-suspenders.

---

## 6. 보고 & 적용

발견 사항을 모아 사용자에게 보고한다:

```
## 🧹 하네스 정리 보고 ({실행 루틴})

### 발견 사항
| # | 분류 | 항목 | 심각도 | 제안 |
|---|------|------|--------|------|
| 1 | 잔존 산출물 | src/foo.test.js | 높음 | 삭제 |
| 2 | 문서 부식 | ARCHITECTURE.md에 없는 utils/ 폴더 | 보통 | 문서 갱신 |
| ... |

### 적용 계획
- 즉시 적용 (승인 시): {삭제/문서 갱신/점수표 갱신 목록}
- TECH_DEBT 항목화: {코드 수정이 필요한 것}
- 다음 TDD 세션 위임: {회귀 복구 등}

적용할까요? (y / 항목 선택 / n)
```

**적용 원칙**:
- **삭제 우선** — 잔존 산출물·죽은 문서 항목은 고치기보다 지운다. 단, 항상 사용자 승인 후
- **scope 제한** — 이 스킬이 직접 수정하는 것은 하네스 문서(AGENTS/ARCHITECTURE/QUALITY_SCORE/TECH_DEBT/feature_list의 상태 필드)와 잔존 산출물 삭제뿐이다. **소스 코드의 동작 변경·리팩터링은 하지 않는다** — TECH_DEBT 항목화 또는 feature_list 등록으로 TDD 사이클에 위임한다
- 적용 후 `npm run validate`로 깨진 것이 없는지 확인한다
- 커밋은 제안만 한다: `chore({scope}): 하네스 정리 — {루틴} ({날짜})`

---

## 7. 정리 로그 기록

`docs/CLEANUP_LOG.md`에 이번 실행을 기록한다. 파일이 없으면 생성한다:

```markdown
# 하네스 정리 로그

> harness-cleanup 스킬의 실행 기록. § 2 루틴 판별의 원천.

| 날짜 | 루틴 | 발견 | 적용 | 비고 |
|------|------|------|------|------|
| {YYYY-MM-DD} | W / W+B / W+B+M | {N}건 | {N}건 | {한 줄 요약} |
```

- 행 추가만 한다 (기존 행 수정/삭제 금지)
- CLEANUP_LOG는 추가형 이벤트 로그라 doc-freshness 검사 대상이 아니다 (staleness 경고 무의미 — 검사 대상 정책: harness-scaffold/SKILL.md § 5.7)
- 하네스 자체의 문제(예: harness:check 구조 항목 실패, 규칙 충돌)를 발견했으면 `.harness-friction.jsonl`에 JSON 한 줄을 append한다 (스키마: `{"ts":"<ISO8601>","session":"<SESSION_ID 또는 \"\">","event":"doc-stale","severity":"low","feature":"","detail":"<소독된 원인 ≤50자>"}`, `setup-mismatch` 등 이벤트 유형 사용) — 반복되면 harness-feedback 스킬로 Issue화한다

---

## 제약 사항

- 소스 코드의 동작을 변경하지 않는다 (리팩터링은 TDD 사이클로 위임)
- 모든 삭제·수정은 사용자 승인 후에만 적용한다
- feature_list.json의 기능 설명(description, steps)을 수정하지 않는다 — 상태 필드(passes, notes, last_session)만 갱신 제안
- claude-progress.txt와 CLEANUP_LOG의 기존 기록을 수정/삭제하지 않는다
- git commit/push는 자동으로 하지 않는다 (제안만)
- 빌드 불가능한 상태를 만들지 않는다 — 적용 후 validate 확인
