# harness-setup

Node.js/TypeScript 프로젝트에 **에이전트 작업 환경(하네스)**을 자동으로 셋업하는 Claude Code 스킬.

소스 코드를 분석하고, 사용자와 문답을 거쳐, 프로젝트에 맞는 문서/설정/검증 스크립트를 생성한다.
기존 소스 코드는 절대 수정하지 않는다.

---

## 하네스란?

에이전트가 프로젝트를 **이해하고, 작업하고, 검증하고, 정리**할 수 있도록 돕는 작업 환경 전체.

하네스가 없는 프로젝트에서 에이전트는 매 세션마다 프로젝트를 처음부터 파악해야 한다. 하네스가 있으면:
- AGENTS.md로 프로젝트 맥락을 즉시 파악
- CLAUDE.md로 작업 규칙과 명령어를 확인
- ARCHITECTURE.md로 아키텍처 규칙을 준수
- feature_list.json으로 진행 상태를 추적
- structural-test.ts로 아키텍처 위반을 자동 감지
- init.sh로 개발 환경을 한 번에 초기화

---

## 실행 흐름

```
Phase 1: 스캔 & 분석
  ├── Step 1: 기초 스캔 (package.json, 디렉토리 구조)
  ├── Step 2: 딥스캔 (import 패턴, 아키텍처 분류)
  ├── Step 3: 프리셋 매칭 (스택+아키텍처 대조)
  ├── Step 4: 소크라테스 문답 (불확실한 부분만 질문, 최대 3라운드)
  └── Step 5: 계획 제시 & 승인
         ↓
[사용자 승인]
         ↓
Phase 2: 스캐폴딩 (12개 파일 생성)
         ↓
Phase 3: 검증 (파일 존재, JSON 유효성, structural-test 실행)
         ↓
Phase 4: 보고 (결과 요약 + 다음 단계 안내)
```

---

## 생성되는 파일

| 파일 | 역할 |
|------|------|
| **AGENTS.md** | 프로젝트 개요, 스택, 아키텍처 링크, 문서 맵 (100줄 이내) |
| **CLAUDE.md** | 명령어, 코드 규칙, 세션 루틴, 금지 사항 (200줄 이내) |
| **ARCHITECTURE.md** | 레이어/슬라이스 규칙, 의존성 방향, 네이밍 규칙 |
| **feature_list.json** | 기능 목록 + 검증 상태 추적 |
| **claude-progress.txt** | 세션별 작업 기록 |
| **init.sh** | 의존성 설치 + 개발 서버 실행 + 준비 확인 |
| **scripts/structural-test.ts** | 아키텍처 의존성 규칙 자동 검증 |
| **scripts/doc-freshness.ts** | 문서 최신성 검사 |
| **docs/QUALITY_SCORE.md** | 6개 카테고리 품질 점수표 |
| **docs/TECH_DEBT.md** | 기술 부채 추적 (4단계 심각도) |
| **docs/{하위 디렉토리}** | product-specs, design-docs, exec-plans, references |
| **package.json** | `lint:arch`, `validate`, `doc:check` 스크립트 추가 |

---

## 지원 아키텍처

| 유형 | 감지 기준 | 검증 내용 |
|------|----------|----------|
| **레이어 기반** (`layer-based`) | types/, lib/, services/, hooks/, components/ 등 | 레이어 의존성 방향 |
| **FSD** (`fsd`) | app/, pages/, widgets/, features/, entities/, shared/ | 레이어 + cross-slice + public API |
| **도메인 기반** (`domain-based`) | 도메인명 폴더 아래 components, hooks 등 | 도메인 간 직접 import 금지 |
| **자유 구조** (`custom`) | 위 패턴에 해당 안 됨 | 문답에서 확인된 규칙만 |

---

## 프리셋 시스템

프리셋은 특정 스택+아키텍처 조합의 기본 프로필이다. `presets/` 폴더에 JSON으로 정의한다.

### 내장 프리셋

| 프리셋 | 스택 | 아키텍처 |
|--------|------|---------|
| `react-next` | React 19 + Next.js 15 (App Router) | 8레이어 (types→...→app) |
| `react-router-fsd` | React + React Router v7 | FSD 6레이어 (shared→...→app) |

### 매칭 로직

1. `detection.required` 패키지 전부 존재하는지 확인
2. `detection.versionConstraints`로 버전 범위 체크 (있을 경우)
3. `architecture.type`이 딥스캔 결과와 일치하는지 확인
4. 여러 후보 → optional 매칭 수 → required 수 → 사용자 선택

### 커스텀 프리셋 추가

`presets/` 폴더에 JSON 파일을 만들면 자동으로 매칭 대상에 포함된다.
필수 필드: `name`, `displayName`, `detection.required`, `architecture.type`, `architecture.layers`, `scripts.lint:arch`, `devServer`, `pathAlias`, `srcRoot`.
기존 프리셋을 복사하여 수정하는 것이 가장 빠르다.

---

## 설치

```bash
# GitHub에서 클론
git clone https://github.com/daehyunk1m/harness-setup-initializer.git \
  ~/.claude/skills/harness-setup

# 업데이트
cd ~/.claude/skills/harness-setup && git pull
```

## 사용

```bash
cd ~/projects/my-project

# 방법 1: 자연어 트리거
claude
> 하네스 셋업해줘

# 방법 2: 슬래시 커맨드
claude
> /harness-setup

# 방법 3: 스킬 디렉토리 직접 지정 (개발/테스트)
claude --add-dir ~/.claude/skills/harness-setup
> 하네스 셋업해줘
```

---

## 디렉토리 구조

```
harness-setup/
├── SKILL.md                          # 스킬 본체 (전체 사양)
├── README.md                         # 이 파일
├── presets/
│   ├── react-next.json               # React + Next.js (App Router, 레이어 기반)
│   └── react-router-fsd.json         # React Router v7 + FSD
├── templates/
│   ├── structural-test-layer.ts      # 레이어 기반 아키텍처 검증 템플릿
│   └── structural-test-fsd.ts        # FSD 아키텍처 검증 템플릿
├── references/
│   ├── harness-guide.md              # 하네스 엔지니어링 이론 (P1~P10)
│   └── project-context.md            # 설계 결정 기록 + 버전 히스토리
├── .claude/
│   └── settings.local.json           # 권한 설정 (WebSearch, WebFetch)
└── .tracking/
    ├── CHANGELOG.md                  # 변경 이력
    ├── TODO.md                       # 작업 추적 (TODO-01~35)
    └── HANDOFF.md                    # 세션 간 컨텍스트 전달
```

### 파일별 역할

| 파일 | 용도 | 누가 읽는가 |
|------|------|------------|
| `SKILL.md` | 스킬의 전체 동작 사양. 4개 Phase, 13개 섹션 | Claude Code (스킬 실행 시) |
| `presets/*.json` | 스택별 기본 프로필 | SKILL.md Phase 1 Step 3 |
| `templates/*.ts` | structural-test 생성의 기반 | SKILL.md Phase 2 |
| `references/*.md` | 설계 배경, 이론적 근거 | 개발자 (참고용), Phase 2에서 부분 참조 |
| `.tracking/*` | 개선 작업 이력 | 개발자 (유지보수 시) |

---

## 주요 설계 결정

### 기존 코드 무수정 원칙
이 스킬은 문서와 설정 파일만 추가한다. 기존 `.ts`, `.tsx`, `.js`, `.css`, `tsconfig.json`, `eslint` 등은 절대 건드리지 않는다. package.json도 `scripts` 필드에 항목을 추가하는 것만 허용한다.

### 소크라테스 문답
고정된 설문지가 아니라, 스캔 결과에서 불확실한 부분만 골라 질문한다. 이미 코드에서 확인된 것은 묻지 않고, 한 번에 3개 이내만 묻는다. 최대 3라운드 후 미확정 항목은 추론값을 사용한다.

### AGENTS.md vs CLAUDE.md 분리
- **AGENTS.md** = "이 프로젝트는 무엇인가" (맥락) — 프로젝트 개요, 아키텍처 설명, 문서 맵
- **CLAUDE.md** = "어떻게 작업할 것인가" (행동) — 명령어, 코드 규칙, 세션 루틴, 금지 사항
- 동일 정보를 중복하지 않는다. CLAUDE.md에서 `@AGENTS.md`로 import.

### 프리셋 우선, 문답 보완
프리셋이 매칭되면 초기 프로필로 사용하고, 문답은 미세 조정에만 사용한다. 매칭 안 되면 문답으로 처음부터 구성한다.

---

## 남은 작업

HANDOFF.md(`.tracking/HANDOFF.md`)에 상세 기록. 주요 미완 항목:

1. **Coding Agent 분기 로직 (P6)** — CLAUDE.md의 세션 루틴이 직선 흐름만 기술. 버그 우선 수정, validate 실패 루프, 3회 실패 에스컬레이션 등 분기 로직을 `.claude/rules/`로 분리 예정.
2. **엔트로피 관리 (P10)** — doc-freshness.ts만 있고 주기적 정리 루프 없음. doc-freshness.ts 확장(코드 메트릭) 또는 별도 cleanup 스킬로 대응 예정.
3. **실전 테스트** — 실제 프로젝트에서 전체 Phase 1~4 통과 검증 필요.
