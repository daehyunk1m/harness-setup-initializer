# Superpowers 연계 매핑 (정본)

> obra/superpowers 스킬 14종의 연계/제외 분류 정본.
> 소비자: `SKILL.md` § 4.2 (Q&A 질문), `harness-scaffold/SKILL.md` § 5.16 (렌더링 규칙)
> 검증 기준일: 2026-06-12 (superpowers v5.1.0, 스킬 디렉토리 전수 확인)
> 갱신 절차: § 4 참조 — 분기마다 카탈로그 변동 리뷰

---

## 1. 연계 (기본 linkedSkills)

스캐폴딩 시 `integrations.superpowers.linkedSkills`의 기본값. AGENTS.md "보조 스킬" 섹션에 렌더링된다.

| 스킬 | AGENTS.md 문구 | 연계 이유 |
|------|---------------|----------|
| `brainstorming` | `- 복잡한 설계 결정/트레이드오프 분석: \`brainstorming\`` | 코어에 구조화된 브레인스토밍 가이드 없음 — 순수 보완 |
| `systematic-debugging` | `- 재현 어려운 버그의 체계적 추적: \`systematic-debugging\` (TDD 중 validate 실패는 agents/debugger.md 우선)` | 코어 Debugger는 TDD 에스컬레이션 전용. 일반 버그 추적 루틴 부재 — 보완 |
| `writing-plans` | `- 다단계 작업의 계획 문서 작성: \`writing-plans\`` | 계획 문서 작성 절차가 코어에 부재 — 보완. PRE-RED 정규 경로는 Architect/Plan 모드 |

`writing-plans` 연계 시 session-routine.md의 `{{INTEGRATION_NOTES}}`에 추가 렌더링:

```
계획 문서의 작성 절차가 필요하면 superpowers의 writing-plans 스킬을 보조로 활용할 수 있다 (PRE-RED 정규 경로는 Architect/Plan 모드).
```

## 2. 선택 (기본 미포함 — 사용자 명시 요청 시만 linkedSkills에 추가)

| 스킬 | AGENTS.md 문구 | 비고 |
|------|---------------|------|
| `using-superpowers` | `- superpowers 스킬 활용 안내: \`using-superpowers\`` | 메타 가이드 |

## 3. 제외 (linkedSkills에 있어도 렌더링하지 않는다)

| 스킬 | 사유 |
|------|------|
| `test-driven-development` | **충돌** — TDD는 코어 정규 경로 (.claude/rules/session-routine.md + agents/ 7종) |
| `requesting-code-review` | **중복** — Reviewer agent + /review 빌트인 |
| `receiving-code-review` | **중복** — Reviewer agent + /review 빌트인 |
| `verification-before-completion` | **중복** — passes 검증 규칙 + validate 루프 + harness:check |
| `executing-plans` | **충돌** — 계획 실행 루프는 TDD 사이클이 정규 경로 |
| `subagent-driven-development` | **충돌** — 코어 자체 subagent 파이프라인 보유 |
| `dispatching-parallel-agents` | **충돌 위험** — 오케스트레이션은 session-routine이 SoT |
| `using-git-worktrees` | **영역 겹침** — 브랜치 정책은 git-workflow.md가 SoT |
| `finishing-a-development-branch` | **충돌** — 세션 종료/커밋 절차는 git-workflow.md + session-routine |
| `writing-skills` | **무관** — 스킬 개발 메타, 하네스 산출물과 접점 없음 |

## 4. 갱신 절차

1. 분기마다 https://github.com/obra/superpowers 의 skills/ 디렉토리를 이 문서와 대조한다
2. **신규 스킬**: 코어 충돌 여부 검토 → 연계(보완)/제외(충돌·중복·무관) 분류 후 이 문서에 추가. 충돌 판정 기준: TDD·코드 리뷰·검증 루프·git 워크플로·오케스트레이션은 코어가 SoT
3. **이름 변경/삭제**: 이 문서를 갱신한다. 기존 하네스의 깨진 참조는 스캐폴딩/업그레이드 시점의 실존 검증(F1.7)이 자동으로 드롭·경고하므로 긴급하지 않다
4. 매핑 변경은 MINOR 범프 대상이 아니다 (references/는 Public API 밖) — 단, 렌더링 결과가 바뀌는 기본 linkedSkills 변경은 CHANGELOG에 기록한다
