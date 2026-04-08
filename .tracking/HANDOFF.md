# harness-setup 스킬 개선 핸드오프 문서

> 작성일: 2026-04-08 (갱신 — 2-스킬 분리, Issue #1 해결)
> 목적: 다음 세션에서 남은 개선 작업을 이어받기 위한 컨텍스트 전달

---

## 1. 현재 상태 요약

### 완료된 작업 (TODO-01 ~ TODO-44, TODO-52)

- **Session 1~2 (04-04)**: SKILL.md 사양 갭 메우기, 템플릿 생성, 프리셋 정합성, CLAUDE.md 생성 규칙 (TODO-01~22)
- **Session 3 (04-05~06)**: 전체 코드베이스 분석 → 20개 이슈 발견 → 4단계(Phase A~D) 수정 (TODO-23~35)
  - Phase A: 템플릿 정규식 버그 수정, re-export 감지, CLAUDE.md 아키텍처 분기
  - Phase B: passes 판정 기준, 문답 종료 조건/우선순위, readyCheck, 동점 해소, mkdir 보장, 누락 레이어 경고
  - Phase C: 프리셋 버전 체크, 다중 pathAlias, docFreshnessDays, 재스캔/재생성 플로우
  - Phase D: 프리셋 작성 가이드, 역할 경계 source of truth, 섹션 재정렬
- **Session 9 (04-07)**: 업그레이드 시스템 설계 (TODO-43)
  - `.harness-manifest.json` 매니페스트 스키마 (전체 프로필 + 파일별 해시/카테고리)
  - 파일 카테고리: managed(13) / custom(4) / data(5)
  - 업그레이드 Phase U1~U5 + 부트스트랩 마이그레이션 (v0→v3.3)
  - 마이그레이션 레지스트리 형식 + 체이닝 규칙
  - 설계 문서: `references/upgrade-system-design.md`
- **Session 10 (04-07)**: 업그레이드 시스템 SKILL.md 구현 (TODO-44)
  - § 2 업그레이드 트리거, § 3 Step 0 모드 판별 분기
  - § 5.13 manifest 생성 규칙, § 5 생성순서 18번 추가
  - § 6.12 manifest 검증, § 7 보고 업데이트
  - § 14 업그레이드 시스템 전체 (14.1~14.6): 매니페스트, 카테고리, U1~U5, 레지스트리, 부트스트랩, 엣지케이스
- **Session 12 (04-08)**: 2-스킬 분리 — GitHub Issue #1 해결 (TODO-52)
  - SKILL.md를 분석 스킬(SKILL.md) + 스캐폴딩 스킬(SKILL-SCAFFOLD.md)로 분리
  - `context: fork`와 멀티턴 Q&A 비호환 문제 해결
  - `.harness-profile.json` 중간 포맷으로 두 스킬 간 계약 수립

상세 변경 이력: `.tracking/CHANGELOG.md` 참조
투두 상태: `.tracking/TODO.md` 참조

### 현재 스킬 구조 (2-스킬 분리)

**SKILL.md (harness-setup)** — 분석 + Q&A 전용
- 프로젝트를 스캔 → 소크라테스 문답 → `.harness-profile.json` 저장
- `context: fork` 없음 — 메인 세션에서 멀티턴 Q&A 수행
- 완료 후 사용자에게 `/harness-scaffold` 실행 안내

**SKILL-SCAFFOLD.md (harness-scaffold)** — 스캐폴딩 + 검증 + 보고 전용
- `.harness-profile.json` 읽기 → 18개 파일 생성 → 검증 → 보고
- `context: fork` + `model: sonnet` — 서브에이전트로 분리 실행 (구조화된 작업)
- 생성 파일: CLAUDE.md, AGENTS.md, ARCHITECTURE.md, agents/*.md (7개), .claude/rules/ (3개), feature_list.json, claude-progress.txt, init.sh, scripts/structural-test.ts, scripts/doc-freshness.ts, docs/QUALITY_SCORE.md, docs/TECH_DEBT.md, docs/HARNESS_FRICTION.md, docs/ 하위 디렉토리, package.json scripts, .harness-manifest.json

**`.harness-profile.json`** — 두 스킬 간 계약(contract)
- 분석 스킬이 출력하고 스캐폴딩 스킬이 입력으로 사용하는 중간 포맷

### 업그레이드 시스템 (v3.3+)
- Step 0 모드 판별: Setup / Bootstrap+Upgrade / Upgrade
- `.harness-manifest.json`으로 버전 추적 (프로필, 파일 해시, 카테고리)
- 파일 카테고리: managed(13) / custom(4) / data(5) — 카테고리별 업그레이드 동작 차별화
- Phase U1~U5: 분석→계획제시→실행→검증→보고
- 마이그레이션 레지스트리: M-{from}-to-{to} 형식, 체이닝 지원
- 부트스트랩: manifest 없는 기존 프로젝트를 v3.3으로 편입
- 엣지 케이스 6개 처리 (중단, 새 플레이스홀더, 프리셋 삭제, 파일 삭제, 아키텍처 변경, 팀 환경)

### 피드백 수집 시스템 (v3.3)
- session-routine.md가 6개 마찰 이벤트(에스컬레이션, 검증 실패 등)를 자동 감지하여 `docs/HARNESS_FRICTION.md`에 기록
- 컴패니언 스킬 구조: `companion-skills/harness-feedback/` (스텁, 향후 구현)
- Phase 4 보고에서 컴패니언 스킬 `--add-dir` 안내

### 모델 설정 (2-스킬 분리 후)
- **SKILL.md (harness-setup)**: `context: fork` 없음, `model: sonnet` 없음 — 메인 세션에서 직접 실행. 멀티턴 Q&A가 필요하므로 fork 불가
- **SKILL-SCAFFOLD.md (harness-scaffold)**: `context: fork` + `model: sonnet` — 서브에이전트로 분리 실행. 구조화된 작업(파일 생성→검증→보고)이므로 Sonnet으로 충분
- 분리 이유: `context: fork`는 서브에이전트로 분리되어 사용자와 멀티턴 대화가 불가능. 소크라테스 문답(Phase 1)이 fork 모드에서 동작 불가 (GitHub Issue #1)

### 하네스 엔지니어링 P1-P10 대비 커버리지

| 프로세스 | 상태 | 비고 |
|----------|------|------|
| P1 저장소 뼈대 | ✅ 완료 | |
| P2 문서 체계 | ✅ 완료 | AGENTS.md + CLAUDE.md 역할 분리 + source of truth 명시 |
| P3 아키텍처 레이어 | ✅ 완료 | 다중 alias, 하이픈 폴더명, re-export 지원 |
| P4 기능 리스트 | ✅ 완료 | passes 판정 기준 구체화 |
| P5 Initializer Agent | ✅ 스킵 | 스킬 자체가 초기화 역할 — 별도 프롬프트 불필요 |
| P6 Coding Agent 루틴 | ✅ 완료 | TDD subagent 파이프라인 (7 agents) + .claude/rules/ 분리 |
| P7 검증 피드백 루프 | ✅ 완료 | 재스캔/재생성 플로우 추가 |
| P8 아키텍처 자동 검사 | ✅ 완료 | 버전 체크, 동점 해소, 누락 레이어 경고 |
| P9 품질/부채 관리 | ✅ 완료 | docFreshnessDays 파라미터화 |
| P10 엔트로피 관리 | 📌 범위 밖 | doc-freshness.ts 감지로 충분, 주기적 정리는 별도 cleanup 스킬 영역 |

---

## 2. 완료된 작업: TDD Subagent 파이프라인 (P6) — 2026-04-06

### 구현 내용

Coding Agent 그룹을 **TDD 중심의 Claude Code subagent 시스템**으로 구체화했다.

**추가된 템플릿:**
- `templates/agents/` — 7개 subagent 정의 (architect, test-engineer, implementer, reviewer, simplifier, debugger, security-reviewer)
- `templates/rules/session-routine.md` — TDD 오케스트레이션 플로우, 상태 머신, 에스컬레이션 규칙
- `templates/rules/coding-standards.md` — 아키텍처/네이밍 규칙 (CLAUDE.md에서 이관)

**SKILL.md 수정:**
- 섹션 5.10 (agents/ 생성 규칙) 추가
- 섹션 5.11 (.claude/rules/ 생성 규칙) 추가
- 섹션 5.1.1 (CLAUDE.md 생성 규칙) 업데이트 — Agent Dispatch 테이블, 코드 규칙을 rules/로 이관
- Phase 2 생성 순서 12 → 15 항목으로 확장
- Phase 3 검증에 agents/, .claude/rules/, 플레이스홀더 치환 검사 추가
- Phase 4 보고에 TDD 워크플로 안내 추가

**TDD 사이클 (Red → Green → Refactor):**
```
Architect (설계) → Test Engineer (Red) → Implementer (Green)
  → Reviewer (리뷰) → Simplifier (Refactor, 조건부)
  → Security Reviewer (보안, 조건부)
  → Debugger (에스컬레이션, on-demand)
```

**핵심 설계 결정:**
- Orchestrator는 subagent가 아님 — CLAUDE.md + .claude/rules/session-routine.md
- CLAUDE.md는 150줄 이내로 슬림화 (상세는 .claude/rules/에 위임)
- 에이전트 호출은 Claude Code의 Agent tool 사용
- 에스컬레이션: Implementer 3회 → Debugger 2회 → 사용자

---

## 3. 범위 밖으로 확정된 항목

### P10 엔트로피 관리 → 별도 스킬로 분리

**결정 (2026-04-07)**: 하네스 셋업 스킬의 범위는 "초기 환경 구성"이다. 주기적 정리 루프는 운영 영역이므로 별도 cleanup 스킬로 분리한다. 현재 스킬에서는 doc-freshness.ts(감지)로 충분하다.

향후 cleanup 스킬 설계 시 참고할 패턴은 oh-my-claudecode의 ai-slop-cleaner (4유형 엔트로피 타겟, 삭제 우선, scope 제한).

---

## 4. 참고: oh-my-claudecode 핵심 패턴

다음 세션에서 참고할 수 있도록 핵심 패턴을 정리한다.

### 디렉토리 구조

```
oh-my-claudecode/
├── CLAUDE.md                  # 프로젝트 "헌법" (에이전트 카탈로그, 품질 규칙, 운영 원칙)
├── .claude/settings.json      # 환경 설정
├── agents/                    # 19개 에이전트 정의 (executor, architect, verifier 등)
│   ├── executor.md            # 구현 전문 (최소 변경, 3회 실패 시 에스컬레이션)
│   ├── architect.md           # 읽기 전용, 아키텍처 분석/지침
│   └── ...
├── skills/                    # 36개 스킬 (autopilot, ralph, team 등)
│   ├── ralph/SKILL.md         # 검증/수정 루프 (Story 선택 → 구현 → 검증 → deslop)
│   ├── ai-slop-cleaner/       # 엔트로피 정리 (4유형, 삭제 우선)
│   └── cancel/                # 의존성 인식 정리 + resume
├── hooks/hooks.json           # 20개 훅 (11개 라이프사이클 이벤트)
└── .omc/                      # 상태 관리
    ├── state/                 # 실행 모드 추적
    ├── sessions/              # 세션 요약
    └── project-memory.json    # 크로스세션 규칙
```

### 핵심 패턴 요약

| 패턴 | 설명 | 우리 스킬 적용 가능성 |
|------|------|---------------------|
| **Rules 분리** | CLAUDE.md는 간결, 상세는 rules/로 | ✅ 바로 적용 |
| **3회 실패 에스컬레이션** | 반복 실패 시 접근 전환 | session-routine.md에 포함 가능 |
| **검증/수정 루프** (Ralph) | 구현→검증→실패시 수정→재검증 | session-routine.md에 포함 가능 |
| **삭제 우선 정리** (ai-slop-cleaner) | 추가보다 삭제 선호 | 향후 cleanup 스킬로 |
| **상태 영속성** (.omc/state/) | 세션 간 상태 보존 | 현재 claude-progress.txt로 커버 |
| **Hook 기반 자동화** | 라이프사이클 이벤트에 스크립트 연결 | 향후 확장 |
| **에이전트 전문화** | executor/architect/verifier 분리 | 현재 범위 밖 (단일 에이전트) |

### `.claude/rules/` 활용 방법 (Claude Code 공식)

```markdown
---
paths:
  - "src/features/**/*.ts"
---

# Feature Module Rules
- exports는 파일 끝에 배치
- barrel export는 index.ts에서만
```

- `paths` 없으면: 세션 시작 시 항상 로딩
- `paths` 있으면: 해당 경로 파일 접근 시 on-demand 로딩
- 형식: Markdown + YAML frontmatter
- `.claude/rules/` 하위 재귀 탐색

---

## 5. 향후 작업 (우선순위)

### 5.1 실전 적용 준비도 분석 결과 (2026-04-07)

Session 11에서 SKILL.md/템플릿/프리셋 전수 분석을 수행했다. **결론: 수정 없이 바로 실행 가능하지만, 7개 리스크/제한사항이 있다.**

- SKILL.md 100% 완성 (14개 섹션, TODO/FIXME 없음)
- 템플릿 17개 전부 존재 + 실제 내용 (스텁 아님)
- 플레이스홀더 21개 전부 소스→기본값 매핑 완료
- 프리셋 2개 (react-next, react-router-fsd) — 커버리지가 좁은 것이 주요 제한

상세: `.claude/plans/humble-dancing-pine.md`

### 5.2 우선순위 목록

1. **2-스킬 플로우 실전 테스트** — `/harness-setup` → `.harness-profile.json` → `/harness-scaffold` 전체 플로우 검증 (TODO-53)
2. **`.harness-profile.json` 스키마 정합성 확인** — 두 스킬 간 계약 문서화 (TODO-54)
3. **실전 테스트 + 피드백 반영** — React Router + FSD 프로젝트에서 첫 실전 테스트. 관찰 포인트 7개 정의됨 (TODO-51)
4. **react-router-fsd versionConstraints 추가** — v6 이하 오매칭 방지 (TODO-45)
5. **추가 프리셋** — react-vite.json (TODO-48), express-api.json (TODO-49)
6. **structural-test 동적 생성 구체화** — domain-based/custom 유형 (TODO-46)
7. **feature_list.json 추론 정책 명시** — 빈 배열 vs 라우트 추출 (TODO-47)
8. **에이전트 템플릿 실전 조정** — TDD subagent 프롬프트 최적화
9. **첫 마이그레이션 작성** — § 14.4 레지스트리에 M-3.3-to-{next} 추가
10. **컴패니언 스킬 구현** — harness-feedback (TODO-50)
11. **Cleanup 스킬 (별도 프로젝트)** — P10 엔트로피 관리 자동화

---

## 6. 파일 위치 안내

```
~/.claude/skills/harness-setup/
├── SKILL.md                          # 분석 스킬 (Phase 1: 분석 + Q&A → 프로필)
├── SKILL-SCAFFOLD.md                 # 스캐폴딩 스킬 (Phase 2~4: 생성 + 검증 + 보고)
├── presets/
│   ├── react-next.json               # React+Next.js 프리셋
│   └── react-router-fsd.json         # React Router+FSD 프리셋
├── templates/
│   ├── structural-test-layer.ts      # 레이어 기반 구조 테스트
│   ├── structural-test-fsd.ts        # FSD 구조 테스트
│   ├── init.sh                       # 환경 초기화 스크립트
│   ├── doc-freshness.ts              # 문서 최신성 검사 스크립트
│   ├── QUALITY_SCORE.md              # 품질 점수표
│   ├── TECH_DEBT.md                  # 기술 부채 문서
│   ├── HARNESS_FRICTION.md           # 마찰 로그
│   ├── agents/                       # TDD subagent 정의 (7개)
│   └── rules/                        # .claude/rules/ 템플릿 (3개)
├── companion-skills/
│   └── harness-feedback/             # 피드백 분석→Issue 스킬 (스텁)
├── references/
│   ├── harness-guide.md              # 이론적 기반 (P1-P10)
│   ├── project-context.md            # 설계 결정 기록
│   └── upgrade-system-design.md      # 업그레이드 시스템 설계
└── .tracking/
    ├── TODO.md                       # 투두 상태 (01-44,52 완료)
    ├── CHANGELOG.md                  # 변경 이력
    └── HANDOFF.md                    # 이 파일
```
