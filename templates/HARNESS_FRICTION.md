# 하네스 마찰 로그

> 이 파일은 TDD 세션 중 발생한 마찰 이벤트를 자동으로 기록한다.
> 하네스 개선 피드백으로 활용된다. 수동 메모도 자유롭게 추가 가능.

## 이벤트 유형

| 이벤트 | 심각도 | 설명 |
|--------|--------|------|
| `implementer-retry` | high | Implementer 2회 이상 실패 후 재시도 |
| `debugger-escalation` | critical | Implementer 한도 초과 → Debugger 호출 |
| `user-escalation` | critical | Debugger도 실패 → 사용자 개입 필요 |
| `review-fix` | medium | Reviewer가 NEEDS_FIX 반환 |
| `refactor-rollback` | high | Simplifier 2회 실패 → 리팩터링 전체 롤백 |
| `session-incomplete` | low | TDD 사이클 미완료 상태로 세션 종료 |

## 로그

| 날짜 | 이벤트 | 심각도 | feature | 상세 |
|------|--------|--------|---------|------|
