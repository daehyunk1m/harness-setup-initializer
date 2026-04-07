---
name: harness-feedback
description: "하네스 마찰 로그(docs/HARNESS_FRICTION.md)를 분석하여 반복 패턴을 식별하고, harness-setup 리포에 개선 Issue를 생성하는 스킬. '피드백 분석', '하네스 피드백', 'harness feedback', '마찰 분석' 등을 요청할 때 사용한다."
---

# Harness Feedback Skill

> **상태: 스텁** — 향후 구현 예정. 아래는 설계 명세.

## 목적

프로젝트의 `docs/HARNESS_FRICTION.md`에 누적된 마찰 이벤트를 분석하여:
1. 반복되는 패턴을 식별한다 (예: 특정 유형의 에스컬레이션이 3회 이상)
2. 패턴별 개선 제안을 정리한다
3. harness-setup 리포에 GitHub Issue를 생성한다

## 실행 흐름 (향후)

```
1. docs/HARNESS_FRICTION.md 읽기
2. 이벤트 유형별 빈도 집계
3. 반복 패턴 식별 (동일 이벤트 3회+, 또는 critical 1회+)
4. 패턴별 개선 제안 생성
5. GitHub Issue 생성 (gh issue create)
   - repo: daehyunk1m/harness-setup-initializer
   - label: feedback
   - title: "[Friction] {패턴 요약}"
   - body: 이벤트 목록 + 개선 제안
```

## 참고

- 마찰 로그 형식: session-routine.md의 "마찰 로그" 섹션 참조
- 이 스킬은 `claude --add-dir ~/.claude/skills/harness-setup/companion-skills/harness-feedback`으로 활성화
