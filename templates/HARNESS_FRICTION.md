# 하네스 마찰 로그

> 이 파일은 TDD 세션 중 발생한 마찰 이벤트를 자동으로 기록한다.
> 하네스 개선 피드백으로 활용된다. 수동 메모도 자유롭게 추가 가능.

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

## 로그

| 날짜 | 이벤트 | 심각도 | feature | 상세 |
|------|--------|--------|---------|------|

## 이슈 보고

이 로그에 critical/high 이벤트가 반복되면, harness-setup 레포에 이슈를 생성해주세요:

1. **자동**: "하네스 피드백 분석해줘" → 마찰 로그를 분석해서 GitHub Issue를 자동 생성
2. **수동**: https://github.com/daehyunk1m/harness-setup-initializer/issues/new
