# 설계 스펙: 마찰 자동 기록 — 저비용 JSONL 싱크

- **이슈**: #9 (HARNESS_FRICTION.md 자동 기록 메커니즘 부재 — 피드백 루프 dead-letter)
- **트래킹**: TODO-84
- **버전 영향**: 1.17.0 → 1.18.0 (MINOR — 새 managed 데이터 파일 + 생성/소비 경로 변경, 하위 호환)
- **작성일**: 2026-06-16
- **상태**: 설계 확정 대기 (옵션 i — Stop hook 없음)

---

## 1. 배경 & 문제

생성 하네스의 `docs/HARNESS_FRICTION.md`는 6종 TDD 이벤트 + 7종 하네스 이슈 카테고리를 정의하고 "자동으로 기록한다"고 명시하지만, **실제 자동 기록 메커니즘이 없다.** `session-routine.md`에 "마찰 로그 테이블에 행을 추가한다"는 산문 지시만 있어 오케스트레이터가 매 세션 잊는다. 결과적으로 로그는 항상 빈 테이블이고, 이를 입력으로 삼는 `harness-feedback` 스킬은 분석 데이터가 0건이 되어 피드백 루프가 dead-letter 상태다 (haja-web-fe 1개월 실사용에서 헤더만 남고 0건).

**근본 원인 재진단**: 마찰 이벤트는 오케스트레이터가 발생 즉시 안다. 실패 지점은 "감지"가 아니라 **마크다운 테이블에 행을 끼워넣는 작업이 무겁고(읽기→테이블 탐색→행 삽입→재작성) 부하 상황에서 건너뛰어진다**는 것이다.

## 2. 목표 / 성공 기준 / 비목표

- **목표**: 마찰 이벤트가 산문 의존을 최소화한 **저비용 단일 append**로 기록되어, `harness-feedback`이 분석할 실데이터가 쌓이게 한다.
- **성공 기준**: TDD 세션에서 마찰이 발생하면 `.harness-friction.jsonl`에 줄이 쌓이고, `harness-feedback`이 빈 로그가 아닌 실 이벤트를 본다. 깨진 줄 하나가 전체 분석을 죽이지 않는다.
- **비목표 (이번 증분 제외)**: Claude Code Stop hook / `.claude/settings.json` 강제, 마크다운 렌더러, 로그 로테이션, 중기안(attempt 카운터 자동화). → 본 메커니즘으로 "기록이 실제로 되는지" 측정 후 후속 증분에서 재검토.

## 3. 아키텍처 결정 (옵션 i — Stop hook 없음)

멀티모델 자문(codex 정확성 / gemini 단순화, `.claude/artifacts/consult/` 2026-06-16) 결과를 반영한다.

- **두 모델 합의**: JSONL 싱크 채택은 옳다. `echo`로 LLM이 직접 JSON 직렬화하는 것은 위험(특수문자). always-on이 맞다.
- **충돌 → 종합 판정**: codex는 "훅·렌더러 유지하되 하드닝", gemini는 "훅·렌더러·node 제거". 프로젝트의 **스택 비종속 원칙**과 보수적 *measure-first* 자세에 따라 **gemini의 단순화를 주축**으로 채택하고, codex의 견고성 디테일(깨진 줄 격리, 고유 세션 ID, detail 소독)을 흡수한다.
- **Stop hook을 두지 않는 이유**: ① 훅 발화는 보장되지 않아(크래시/강제종료) 안전망 이상이 될 수 없다(codex), ② 렌더러를 폐기하면 훅에 남는 일은 `claude-progress.txt` 휴리스틱 백필뿐인데 false-positive 위험이 있다(codex), ③ 훅은 하네스의 첫 `.claude/settings.json` + merge upsert + node-on-by-default + 업그레이드 마이그레이션을 끌고 온다, ④ 주 메커니즘(싼 append)이 실제 부하를 진다. 측정 후 누락이 확인되면 후속 증분에서 추가한다.

## 4. 데이터 모델

### 4.1 `.harness-friction.jsonl` (진실 원본, 프로젝트 루트)

append-only, git 커밋. 한 줄 = 1 이벤트:

```json
{"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-a3f9","event":"implementer-retry","severity":"high","feature":"F-12","detail":"타입 에러 3회 반복"}
```

| 필드 | 의미 | 비고 |
|------|------|------|
| `ts` | 이벤트 발생 시각 (ISO8601 UTC) | |
| `session` | 세션 고유 ID | § 4.2 — 날짜 단독은 충돌(codex 5번) |
| `event` | 이벤트 유형 enum | § 4.3 |
| `severity` | `low`\|`medium`\|`high`\|`critical` | |
| `feature` | feature ID 또는 `""` | |
| `detail` | 소독된 원인 한 줄 (≤50자) | § 6.1 소독 규칙 |

### 4.2 세션 ID

세션 시작 시 1회 생성해 `claude-progress.txt`에 `SESSION_ID: <값>`으로 기록하고, 그 세션의 모든 마찰 줄이 동일 값을 참조한다. 형식: `{ISO 시각}-{4자 난수}` 예 `2026-06-16T09-12-03Z-a3f9`. → `harness-feedback`이 세션 단위로 그룹핑·패턴 분석할 때 같은 날 복수 세션을 구분한다.

### 4.3 이벤트 유형 (기존 정의 유지)

TDD: `implementer-retry`(high), `debugger-escalation`(critical), `user-escalation`(critical), `review-fix`(medium), `refactor-rollback`(high), `e2e-fail`(high), `session-incomplete`(low).
하네스 이슈: `setup-mismatch`, `structural-test-false-positive/negative`, `init-failure`, `rule-conflict`, `agent-hallucination`, `doc-stale` (harness-cleanup가 기록).

## 5. 컴포넌트

### 5.1 싱크 생성
스캐폴드 시 빈 `.harness-friction.jsonl`을 생성한다(harness-feedback이 파일 부재와 0건을 구분). manifest에 **category `data`로 등록**(템플릿 해시 드리프트 검사 제외 — feature_list와 동일 취급).

### 5.2 오케스트레이터 append (주 메커니즘)
`session-routine.md`의 마찰 기록을 "테이블 행 삽입"에서 **단일 JSON 라인 append**로 교체한다:

```
echo '{"ts":"...","session":"<SESSION_ID>","event":"implementer-retry","severity":"high","feature":"F-12","detail":"<소독된 한 줄>"}' >> .harness-friction.jsonl
```

- 기록 시점은 기존과 동일(루프 의사코드 L129/133/147/162/202/217/253 + § 마찰 로그).
- **중복 억제**: 같은 세션·feature·event 첫 회만(오케스트레이터가 세션 내에서 판단 — 동일 에이전트라 기억 가능).

### 5.3 `HARNESS_FRICTION.md` 격하 (정적 참조 문서)
`## 로그` 테이블과 자동 렌더 개념을 제거한다. 남기는 것: 이벤트 유형/심각도 참조표, 이슈 보고 안내, 그리고 "이벤트는 `.harness-friction.jsonl`에 자동 기록되며 '하네스 피드백 분석해줘'로 분석한다"는 포인터. → 렌더러·마커·escape-in-md 문제(codex 2·6번)와 SSoT·git 노이즈(gemini)가 동시에 소멸.

### 5.4 `harness-feedback` — jsonl 직접 파싱
- 입력을 `docs/HARNESS_FRICTION.md`(테이블) → `.harness-friction.jsonl`로 변경. `cat .harness-friction.jsonl` 후 줄 단위로 읽는다(allowed-tools `Bash(cat *)` 유지, JSON 파싱은 LLM 내부 — jq 등 외부 의존 없음).
- **관용 파싱**: JSON 파싱 실패한 줄은 건너뛰고, 건너뛴 수를 보고한다(codex 3·9번 — 깨진 한 줄이 전체 분석을 죽이지 않음).
- 파일 부재 → "not found". 0줄 → "기록된 이벤트 없음".
- 이슈 본문 md 테이블 작성 시 detail의 `|`·줄바꿈을 escape.
- 그룹핑·보고 임계값(critical 1회+/동일 2회+/high 2회+)은 기존 유지.

## 6. 안전성

### 6.1 detail 소독 (오케스트레이터 책임, node 강제 없이)
detail은 Claude가 쓰는 **비적대적 입력**이므로 소독+관용 파싱으로 충분하다(codex가 권한 별도 node 직렬화 스크립트는 스택 비종속 위배로 불채택). 소독 규칙: 큰따옴표 `"`→`'`, 줄바꿈/CR 제거(공백), 백슬래시 `\` 제거, ≤50자 절단. `session-routine.md`에 명시.

### 6.2 수용한 리스크 / 후속
- **동시 쓰기·부분 쓰기**: 저빈도·비임계 로그라 POSIX 단일 라인 append로 충분. 잔여는 § 5.4 관용 파싱이 흡수.
- **무한 성장**: 세션당 이벤트 수가 적어 v1 비대상. 로테이션은 후속 증분 후보로 명시(codex 9번).

## 7. 변경 파일 (harness-setup 리포)

| 파일 | 변경 |
|------|------|
| `templates/HARNESS_FRICTION.md` | 로그 테이블 제거, 정적 참조 문서로 격하(§5.3) |
| `templates/rules/session-routine.md` | 마찰 기록 → jsonl 1줄 append + 소독 규칙(§6.1); § 세션 시작에 SESSION_ID 생성/기록; § 세션 종료에 미완료 시 `session-incomplete` append |
| `harness-scaffold/SKILL.md` | 생성 순서에 빈 `.harness-friction.jsonl` 추가, manifest category `data` 등록, HARNESS_FRICTION.md 생성 규칙 갱신. (settings.json·friction-detect.mjs 없음) |
| `SKILL.md` | 계약 동기화(새 managed 데이터 파일 반영). 프로필 신규 필드 없음(always-on). Phase 4 "이제 할 수 있는 일" 카탈로그에 마찰 자동 기록을 광고 가능(always-on이라 게이트 무관) |
| `companion-skills/harness-feedback/SKILL.md` | 입력을 jsonl로 + 관용 파싱 + escape(§5.4) |
| `references/harness-checklist.md` | 필수 managed 파일에 `.harness-friction.jsonl` 추가 |
| `templates/harness-check.sh` | (선택) ① 필수 파일 점검에 `.harness-friction.jsonl` 포함 |
| 트래킹 5종 + `git tag` | TODO-84 클로즈, 1.18.0, CHANGELOG/HANDOFF/project-context, 이슈 #9 클로즈 |

## 8. 업그레이드 경로 (기존 하네스)

`harness upgrade` 시: ① `session-routine.md`·`HARNESS_FRICTION.md` 재렌더, ② 빈 `.harness-friction.jsonl` 생성 + manifest 등록. `harness-feedback`은 **글로벌 컴패니언 스킬**(`~/.claude/skills/`)이라 install.sh로 배포되며 **프로젝트별 마이그레이션 불필요**. 기존 md 로그 테이블에 행이 있던 경우(실측상 비어 있음)에 한해 1회 best-effort로 행을 jsonl로 이관한다. → 파괴적 변경 없음.

## 9. 원칙 점검

- **스택 비종속**: jsonl append = bash `echo`(무관). harness-feedback의 jsonl 읽기 = `cat` + LLM 파싱(외부 도구 0). node 훅·렌더러 없음 → gemini의 node 우려 자체가 소멸. ✓
- **소스 코드 미수정**: 문서·데이터 파일만. ✓
- **두 SKILL.md 계약 동기화**: §7에 반영. ✓
- **능력 광고 규칙**: 마찰 자동 기록은 always-on이라 Phase 4 카탈로그에 무조건 광고 가능(미와이어 광고 아님). ✓

## 10. 범위 밖 (YAGNI)

Stop hook/settings.json 강제, md 렌더러, 로그 로테이션, 중기 attempt 카운터 자동화, harness-feedback의 dead-letter 메시지 세분화. → 본 증분으로 데이터가 실제로 쌓이는지 측정 후 재검토.

## 11. 검증 계획

1. 스캐폴드 픽스처에서 TDD 세션을 돌려 implementer-retry를 유발 → `.harness-friction.jsonl`에 줄 생성 확인.
2. `harness-feedback` 실행 → jsonl을 읽고 보고하는지 확인.
3. jsonl에 깨진 줄을 삽입 → harness-feedback이 해당 줄만 스킵하고 나머지를 분석하는지 확인.
4. 기존 픽스처 업그레이드 → jsonl 생성 + session-routine 재렌더 확인.
5. `bash test/run-fixtures.sh`(골든 픽스처 회귀) 영향 없음 확인.
