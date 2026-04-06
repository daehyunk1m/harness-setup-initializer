# harness-setup 스킬 개선 핸드오프 문서

> 작성일: 2026-04-06 (갱신)
> 목적: 다음 세션에서 남은 개선 작업을 이어받기 위한 컨텍스트 전달

---

## 1. 현재 상태 요약

### 완료된 작업 (TODO-01 ~ TODO-35)

- **Session 1~2 (04-04)**: SKILL.md 사양 갭 메우기, 템플릿 생성, 프리셋 정합성, CLAUDE.md 생성 규칙 (TODO-01~22)
- **Session 3 (04-05~06)**: 전체 코드베이스 분석 → 20개 이슈 발견 → 4단계(Phase A~D) 수정 (TODO-23~35)
  - Phase A: 템플릿 정규식 버그 수정, re-export 감지, CLAUDE.md 아키텍처 분기
  - Phase B: passes 판정 기준, 문답 종료 조건/우선순위, readyCheck, 동점 해소, mkdir 보장, 누락 레이어 경고
  - Phase C: 프리셋 버전 체크, 다중 pathAlias, docFreshnessDays, 재스캔/재생성 플로우
  - Phase D: 프리셋 작성 가이드, 역할 경계 source of truth, 섹션 재정렬

상세 변경 이력: `.tracking/CHANGELOG.md` 참조
투두 상태: `.tracking/TODO.md` 참조

### 현재 SKILL.md가 하는 일

프로젝트를 스캔 → 소크라테스 문답 → 승인 → 12개 파일 생성 → 검증 → 보고.
생성 파일: CLAUDE.md, AGENTS.md, ARCHITECTURE.md, feature_list.json, claude-progress.txt, init.sh, scripts/structural-test.ts, scripts/doc-freshness.ts, docs/QUALITY_SCORE.md, docs/TECH_DEBT.md, docs/ 하위 디렉토리, package.json scripts.

### 모델 설정
- `context: fork` + `model: sonnet` — 스킬 실행 시 Sonnet 서브에이전트로 분리 실행
- 구조화된 작업(스캔→문답→생성→검증)이므로 Sonnet으로 충분
- 스킬 완료 후 기존 세션 모델(예: Opus)로 자동 복귀
- 2026-04-06 실전 테스트 통과 확인

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
| P10 엔트로피 관리 | **⚠️ 미완** | doc-freshness.ts만 있음, 주기적 정리 루프 없음 |

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

## 3. 남은 작업: 엔트로피 관리 (P10)

### 문제

doc-freshness.ts(문서 최신성 검사)만 있고, 주기적 정리 루프가 없다.
harness-guide.md는 주간/월간 점검을 설명하지만 현재 자동화 수단이 없다.

### oh-my-claudecode에서 배운 패턴

**ai-slop-cleaner 스킬:**
- 4가지 엔트로피 유형 타겟: 중복, 데드 코드, 추상화, 경계 엔트로피
- "삭제 우선" 원칙: 추가보다 삭제를 선호
- 변경된 파일 범위 내에서만 정리 (scope 제한)
- regression 테스트 필수

**cancel 스킬:**
- 의존성 인식 정리 (연결된 모드 함께 취소)
- 상태 보존 (resume 가능)

### 결정 필요

이 부분은 세 가지 접근이 가능:

**A. 최소 접근 — 수동 체크리스트만 생성**
- SKILL.md가 `docs/CLEANUP_CHECKLIST.md`를 생성
- 사용자가 주기적으로 수동 실행
- 장점: 간단, 스킬 복잡도 안 올라감
- 단점: 자동화 없음

**B. 중간 접근 — doc-freshness.ts 확장**
- 기존 doc-freshness.ts를 코드 품질 메트릭까지 확장 (any 카운트, 300줄 초과 파일 등)
- `npm run doc:check`가 문서 + 코드 품질을 함께 검사
- 장점: 기존 인프라 활용
- 단점: 정리 "실행"은 안 함 (감지만)

**C. 별도 스킬 — cleanup 스킬 생성**
- oh-my-claudecode의 ai-slop-cleaner처럼 별도 스킬
- `/cleanup` 으로 호출하면 정리 루프 실행
- 장점: 완전한 자동화
- 단점: harness-setup 스킬 범위를 벗어남, 별도 프로젝트

**권장**: 현 시점에서는 **B**로 시작하고, 필요 시 C로 확장.
이 결정은 다음 세션에서 확정.

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

## 5. 다음 세션 작업 순서 (권장)

### Step 1: `.claude/rules/` 생성 규칙 추가

SKILL.md에 `.claude/rules/` 파일 생성을 추가한다.

**수정 파일**: `SKILL.md`
**수정 내용**:
- Phase 2 생성 순서에 `.claude/rules/` 추가 (CLAUDE.md 다음)
- 새 섹션 "5.x .claude/rules/ 생성 규칙" 추가
  - `session-routine.md` — 분기 로직 포함 세션 루틴
  - `coding-standards.md` — 프로필 기반 코드 규칙
  - 도메인별 rules (프로필에 추가 항목 있을 때만)
- CLAUDE.md에서 코드 규칙/세션 루틴 상세를 rules/로 이관
- Phase 3 검증, Phase 4 보고 업데이트

### Step 2: session-routine.md 내용 정의

harness-guide.md P6의 분기 로직을 session-routine.md 생성 규칙으로 구체화:
- 버그 우선 수정 분기
- validate 실패 → 수정 → 재검증 루프
- 3회 반복 실패 → 접근 전환
- feature 완료 판정 기준

### Step 3: 엔트로피 관리 방향 확정

위 섹션 3의 A/B/C 중 선택. 권장 B부터 시작.

### Step 4: HAJA 프로젝트에서 실전 테스트

```bash
cd ~/projects/haja
claude --add-dir ~/.claude/skills/harness-setup
> 하네스 셋업해줘
```

---

## 6. 파일 위치 안내

```
~/.claude/skills/harness-setup/
├── SKILL.md                          # 스킬 본체 (수정 대상)
├── presets/
│   ├── react-next.json               # React+Next.js 프리셋
│   └── react-router-fsd.json         # React Router+FSD 프리셋
├── templates/
│   ├── structural-test-layer.ts      # 레이어 기반 구조 테스트
│   └── structural-test-fsd.ts        # FSD 구조 테스트
├── references/
│   ├── harness-guide.md              # 이론적 기반 (P1-P10)
│   └── project-context.md            # 설계 결정 기록
└── .tracking/
    ├── TODO.md                       # 투두 상태 (01-22 완료)
    ├── CHANGELOG.md                  # 변경 이력
    └── HANDOFF.md                    # 이 파일
```
