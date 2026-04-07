# 하네스 셋업 스킬 — 프로젝트 컨텍스트

> 이 문서는 하네스 셋업 스킬의 설계 결정 기록이다.
> 스킬 개선 작업 시 배경 맥락으로 참조한다.
>
> 마지막 업데이트: 2026-04-07 (v3.3 + 업그레이드 시스템 구현)

---

## 1. 프로젝트 목적

하네스가 없는 프로젝트에 **에이전트 작업 환경(하네스)**을 자동으로 셋업해주는 Claude Code 스킬.

목표는 oh-my-claudecode 같은 대규모 시스템이 아니라, **작지만 직접 만든 하네스 셋업 도구**를 점진적으로 발전시키는 것이다.

### 핵심 설계 철학

하네스는 **특정 프레임워크나 아키텍처에 종속되지 않는다**. 하네스의 뼈대(AGENTS.md, progress, feature_list, 세션 루틴)는 어떤 스택이든 동일하며, 아키텍처 세부사항(레이어 규칙, 네이밍, 검증 패턴)만 프로젝트마다 다르다. SKILL.md는 범용 뼈대를 담당하고, 프리셋이 아키텍처 지식을 담당한다.

### 이론적 배경

- **Anthropic** "Effective Harnesses for Long-Running Agents" — Initializer + Coding Agent 2단계 패턴, feature_list.json 기반 점진적 진행, 세션 간 핸드오프
- **OpenAI** "Harness Engineering" — 컨텍스트 엔지니어링 + 아키텍처 제약 + 엔트로피 관리 3기둥 체계

통합 가이드: `references/harness-guide.md`

---

## 2. 스킬 디렉토리 구조

```
~/.claude/skills/harness-setup/
├── SKILL.md                      # 스킬 본체 (frontmatter + 지침)
├── presets/                      # 스택별 프리셋
│   ├── react-next.json           # React + Next.js (App Router) + 레이어 기반
│   └── react-router-fsd.json     # React Router v7 + FSD
├── templates/                    # 생성 파일 템플릿
│   ├── structural-test-layer.ts  # 레이어 기반 아키텍처 검증
│   ├── structural-test-fsd.ts    # FSD 아키텍처 검증
│   ├── agents/                   # TDD subagent 정의 템플릿
│   │   ├── architect.md
│   │   ├── test-engineer.md
│   │   ├── implementer.md
│   │   ├── reviewer.md
│   │   ├── simplifier.md
│   │   ├── debugger.md
│   │   └── security-reviewer.md
│   └── rules/                    # .claude/rules/ 템플릿
│       ├── session-routine.md    # TDD 오케스트레이션 플로우
│       └── coding-standards.md   # 아키텍처/네이밍 규칙
└── references/                   # 배경 문서 (스킬 실행 시 자동 로드 안 됨)
    ├── harness-guide.md          # Anthropic + OpenAI 통합 가이드
    └── project-context.md        # 이 파일
```

### 작업 환경

- **개발**: `cd ~/.claude/skills/harness-setup && claude`
- **테스트**: `cd ~/projects/haja && claude --add-dir ~/.claude/skills/harness-setup`
- **호출**: 프로젝트에서 "하네스 셋업해줘" 또는 `/harness-setup`

---

## 3. 설계 결정 사항

| 항목 | 결정 | 근거 |
|------|------|------|
| 실행 환경 | Claude Code CLI | 스킬 시스템과 동일 생태계 |
| 지원 스택 | 프리셋으로 확장 가능한 범용 구조 | v2에서 범용화 |
| 기존 코드 처리 | 안 건드림 — 문서/설정만 추가 | 안전 최우선 |
| 인터랙션 수준 | 소스 분석 → 소크라테스 문답 → 승인 → 생성 | v2에서 문답 단계 추가 |
| 프리셋 시스템 | JSON 프리셋 + 프리셋 없이도 동작 | 문답으로 즉석 프로필 구성 가능 |
| 에이전트 구조 | TDD subagent 파이프라인 (7 agents) | oh-my-claudecode 참조, Coding 그룹 우선 구현 |
| Orchestrator 위치 | CLAUDE.md + .claude/rules/ (subagent 아님) | 핸드오프 비용 최소화, 상태 머신 단순화 |
| TDD 워크플로 | Red → Green → Refactor 강제 | 테스트 없는 기능 완료 방지 |
| 배포 위치 | `~/.claude/skills/` | 글로벌 스킬, 모든 프로젝트에서 사용 |
| 실행 모델 | Sonnet (`context: fork` + `model: sonnet`) | 구조화된 작업이라 Sonnet 충분, 비용/속도 최적화 |
| 피드백 수집 | session-routine 지시 기반 (hook 아님) | TDD 내부 이벤트에 hook 불가, 오케스트레이터 지시로 충분 |
| 컴패니언 스킬 배치 | companion-skills/ + --add-dir opt-in | 자동 활성화 않고 사용자 선택권 보장 |
| 업그레이드 시스템 | A(마이그레이션 레지스트리) + B(파일 카테고리 분리) | 사용자 커스터마이징 보존 + managed 파일 자동 갱신. 상세: `references/upgrade-system-design.md` |
| 버전 추적 | `.harness-manifest.json` (단일 파일) | 파일별 주석 스탬프 대신 하나의 JSON으로 전체 상태 파악. 전체 profile 저장으로 재스캔 없이 재치환 |

---

## 4. 버전 히스토리

### v1 (초기)
- SKILL.md 초안, react-next.json 프리셋
- Next.js 레이어 기반에 하드코딩

### v2 (리팩터링)
- SKILL.md 범용화 — 아키텍처 종속 제거
- 소스 코드 딥스캔 + 소크라테스 문답 단계 추가
- 프로젝트 프로필 개념 도입
- 아키텍처 유형 분류 체계 (layer-based / fsd / domain-based / custom)
- react-router-fsd.json 프리셋 추가
- 프리셋 스키마에 architecture 필드 추가

### v2.1 (Claude Code 스킬 이전)
- `{SKILL_DIR}` 플레이스홀더 → 상대 경로 참조로 변경
- frontmatter description 트리거 최적화
- 디렉토리 구조를 `~/.claude/skills/harness-setup/`에 맞게 정리
- references/ 섹션 추가
- claude.ai 프로젝트에서 Claude Code 스킬로 개발 환경 이전

### v3 (TDD Subagent 파이프라인)
- Coding Agent 그룹을 7개 subagent로 분리 (Architect, Test Engineer, Implementer, Reviewer, Simplifier, Debugger, Security Reviewer)
- TDD Red → Green → Refactor 사이클 기반 오케스트레이션
- `.claude/rules/` 분리 — session-routine.md (TDD 플로우), coding-standards.md (코드 규칙)
- CLAUDE.md 슬림화 (200줄 → 150줄) — 상세 규칙을 .claude/rules/로 이관
- Agent Dispatch 테이블 도입 — 어떤 에이전트를 언제 호출하는지 명시
- 에스컬레이션 체인 — Implementer 3회 → Debugger 2회 → 사용자
- claude-progress.txt에 TDD STATE 블록 포맷 추가 (세션 간 사이클 이어받기)
- oh-my-claudecode 참조 — 에이전트 전문화 패턴, 에스컬레이션 패턴 채용

### v3.3 (피드백 수집 시스템)
- 마찰 자동 감지: session-routine.md에 6개 마찰 이벤트 로깅 지시 추가
- HARNESS_FRICTION.md 템플릿: 기계 파싱 가능한 마크다운 테이블 형식
- 컴패니언 스킬 구조: companion-skills/ 디렉토리 도입, harness-feedback 스킬 스텁
- Phase 4 보고에 운용 스킬 안내 추가 (--add-dir opt-in 방식)

### v3.2 (템플릿 완비 + 트래킹 정리)
- 미생성 템플릿 4개 추가: init.sh, doc-freshness.ts, QUALITY_SCORE.md, TECH_DEBT.md
- SKILL.md 5.6~5.9절에 템플릿 참조 + 플레이스홀더 치환 규칙 추가
- Phase 3 검증 6.11에 새 템플릿 파일 포함
- P10 엔트로피 관리를 "범위 밖"으로 확정 (별도 cleanup 스킬로 분리)
- 트래킹 문서(HANDOFF, project-context, TODO) 현행화

### v4.0 (구현 완료 — 업그레이드 시스템)
- `.harness-manifest.json`: 버전 추적 + 전체 프로필 저장 + 파일별 해시/카테고리
- 파일 카테고리: managed(13개) / custom(4개) / data(5개) 분류
- 업그레이드 모드: Phase U1~U5 (분석 → 계획 → 실행 → 검증 → 보고)
- 마이그레이션 레지스트리: 버전 간 변경을 구조화된 지시로 기술, 순차 적용
- 부트스트랩: manifest 없는 기존 프로젝트를 v3.3으로 간주하여 편입
- SKILL.md § 14로 구현 완료 (TODO-44)
- 설계 문서: `references/upgrade-system-design.md`

---

## 5. 향후 확장 가능 항목

| 항목 | 역할 | 우선순위 |
|------|------|---------|
| ~~업그레이드 시스템 구현~~ | ~~SKILL.md § 14 추가~~ — **구현 완료** (TODO-44) | ~~높음~~ |
| Initializer 그룹 subagent | 하네스 셋업 내부의 subagent 분리 (Scanner/Scaffolder) | 낮음 |
| Cleanup 스킬 (별도 프로젝트) | 엔트로피 관리 — 주기적 정리 루프 | 보통 |
| 추가 프리셋 | react-vite.json, express-api.json 등 | 보통 |

---

## 6. 다음 단계

1. **실전 테스트 + 피드백 반영** — 셋업 + 업그레이드 모두 다양한 프로젝트에서 검증, 프롬프트 조정
2. **추가 프리셋** — react-vite.json, express-api.json 등 지원 스택 확장
3. **에이전트 템플릿 실전 조정** — subagent 프롬프트 최적화
4. **첫 마이그레이션 작성** — 스킬에 실제 변경 발생 시 § 14.4 레지스트리에 M-3.3-to-{next} 추가
5. **Cleanup 스킬 (별도 프로젝트)** — P10 엔트로피 관리 자동화

---

## 7. 핵심 원칙

1. 하네스는 스택에 종속되지 않는다
2. 기존 소스 코드를 수정하지 않는다
3. AGENTS.md는 100줄 이내, 목차 역할
4. 소스 코드를 직접 읽고 분석한다
5. 확신 없는 부분은 사용자에게 묻는다
6. 사용자 승인 없이 파일을 생성하지 않는다
7. 리뷰에서 반복되는 문제는 자동 검사로 승격한다
8. 한 번에 하나의 기능만, 점진적으로
9. 프리셋이 없어도 동작한다

---

## 8. 참고 링크

- Anthropic 공식: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic 퀵스타트: https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding
- OpenAI 원문: https://openai.com/index/harness-engineering/
- FSD 공식: https://feature-sliced.design/
- Claude Code 스킬 문서: https://code.claude.com/docs/en/skills
