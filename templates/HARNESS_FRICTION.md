# 하네스 마찰 로그

> 이 파일은 마찰 이벤트의 **유형/심각도 참조표**다 (정적 문서).
> 실제 이벤트는 프로젝트 루트의 `.harness-friction.jsonl`에 한 줄씩 자동 기록되며,
> "하네스 피드백 분석해줘"로 누적된 로그를 분석해 하네스 개선 피드백으로 활용한다.

## 이벤트 유형

### TDD 세션 이벤트

| 이벤트 | 심각도 | 설명 |
|--------|--------|------|
| `implementer-retry` | high | Implementer 2회 이상 실패 후 재시도 |
| `debugger-escalation` | critical | Implementer 한도 초과 → Debugger 호출 |
| `user-escalation` | critical | Debugger도 실패 → 사용자 개입 필요 |
| `review-fix` | medium | Reviewer가 NEEDS_FIX 반환 |
| `refactor-rollback` | high | Simplifier 2회 실패 → 리팩터링 전체 롤백 |
| `session-incomplete` | low | TDD 사이클 미완료 상태로 세션 종료 |

### 하네스 이슈

| 이벤트 | 심각도 | 설명 |
|--------|--------|------|
| `setup-mismatch` | high | 하네스 셋업이 프로젝트를 잘못 감지 (스택, 아키텍처 등) |
| `structural-test-false-positive` | medium | structural-test가 올바른 코드를 위반으로 보고 |
| `structural-test-false-negative` | high | 실제 위반을 structural-test가 놓침 |
| `init-failure` | high | init.sh 실행 실패 |
| `rule-conflict` | medium | .claude/rules/ 규칙이 프로젝트 실정과 충돌 |
| `agent-hallucination` | high | subagent가 존재하지 않는 API/패턴을 사용 |
| `doc-stale` | low | AGENTS.md/ARCHITECTURE.md 내용이 현재 코드와 불일치 |

## 자동 기록 & 분석

마찰 이벤트는 이 파일이 아니라 프로젝트 루트의 `.harness-friction.jsonl`에 한 줄씩 자동 기록된다 (append-only, git 커밋). 한 줄 = 1 이벤트, JSON Lines 형식:

```json
{"ts":"2026-06-16T12:34:56Z","session":"2026-06-16T09-12-03Z-a3f9","event":"implementer-retry","severity":"high","feature":"F-12","detail":"타입 에러 3회 반복"}
```

| 필드 | 의미 |
|------|------|
| `ts` | 이벤트 발생 시각 (ISO8601 UTC) |
| `session` | 세션 고유 ID (`{ISO 시각}-{4자 난수}`, 예 `2026-06-16T09-12-03Z-a3f9`) |
| `event` | 위 참조표의 이벤트 유형 enum |
| `severity` | `low` \| `medium` \| `high` \| `critical` |
| `feature` | feature ID 또는 `""` |
| `detail` | 소독된 원인 한 줄 (≤50자) |

오케스트레이터(`session-routine.md` 참조)가 마찰 발생 시점에 단일 JSON 라인을 append한다. 누적된 로그는 **"하네스 피드백 분석해줘"**로 분석하면 `harness-feedback`이 `.harness-friction.jsonl`을 파싱해 반복 패턴을 식별하고 개선 Issue를 제안한다.

## 이슈 보고

이 로그에 critical/high 이벤트가 반복되면, harness-setup 레포에 이슈를 생성해주세요:

1. **자동**: "하네스 피드백 분석해줘" → 마찰 로그를 분석해서 GitHub Issue를 자동 생성
2. **수동**: https://github.com/daehyunk1m/harness-setup-initializer/issues/new
