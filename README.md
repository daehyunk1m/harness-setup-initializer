# harness-setup

> 현재 버전: **1.12.0** · 상세 이력: [`.tracking/CHANGELOG.md`](.tracking/CHANGELOG.md)

Node.js/TypeScript 프로젝트에 **에이전트 작업 환경(하네스)**을 자동으로 셋업하는 Claude Code 스킬.

소스 코드를 분석하고, 사용자와 문답을 거쳐, 프로젝트에 맞는 문서/설정/검증 스크립트를 생성한다.
기존 소스 코드는 수정하지 않는다 (옵트인한 설정 보강 제외 — 아래 [설계 결정](#기존-코드-무수정-원칙) 참조).

---

## 하네스란?

에이전트가 프로젝트를 **이해하고, 작업하고, 검증하고, 정리**할 수 있도록 돕는 작업 환경 전체.

하네스가 없는 프로젝트에서 에이전트는 매 세션마다 프로젝트를 처음부터 파악해야 한다. 하네스가 있으면:
- AGENTS.md로 프로젝트 맥락 + 명령어를 즉시 파악 (명령어의 source of truth)
- CLAUDE.md로 작업 규칙·에이전트 디스패치·운영 사이클을 확인
- ARCHITECTURE.md로 아키텍처 규칙을 준수
- `.claude/rules/`로 세션 루틴, 코딩 표준, Git 규칙을 자동 적용
- `agents/*.md`로 TDD subagent 파이프라인을 구동
- feature_list.json으로 진행 상태를 추적
- structural-test.ts로 아키텍처 위반을 자동 감지 (exit 1)
- init.sh로 개발 환경을 한 번에 초기화
- `npm run harness:check`로 하네스 상태를 자가진단 ("표준 하네스 가동" 판정 — 구조 설치·실행 가능성을 확인하며, 문서·규칙의 의미 정확성은 별도 검토 권장)

그리고 운영 단계에서는 **컴패니언 스킬**이 정리·피드백·교차 자문을 돕는다 (아래 [컴패니언 스킬](#컴패니언-스킬) 참조).

---

## 2-스킬 구조

하네스 셋업은 두 개의 스킬이 자동 체이닝으로 연결된다:

| 스킬 | 역할 | 산출물 |
|------|------|--------|
| **`/harness-setup`** | Phase 1: 프로젝트 스캔 + Q&A + 프로필 저장 | `.harness-profile.json` |
| **`/harness-scaffold`** | Phase 2~4: 파일 생성 + 검증 + 보고 | 19개 파일 + `.harness-manifest.json` |

### 자동 체이닝

사용자가 `/harness-setup`만 실행하면 나머지는 자동으로 진행된다:

1. `harness-setup`이 프로필을 저장하면 **Stop hook**이 발동한다
2. 프로필은 있지만 매니페스트가 없으므로 hook이 `block`을 반환한다
3. `additionalContext`로 `/harness-scaffold` 호출을 지시한다
4. scaffold가 모든 파일을 생성하고 매니페스트를 저장하면 hook이 `allow`를 반환한다

---

## 실행 흐름

```mermaid
stateDiagram-v2
    [*] --> 상태감지

    state 상태감지 <<choice>>
    상태감지 --> Phase1 : profile ✗ manifest ✗
    상태감지 --> 프로필재사용 : profile ✓ manifest ✗
    상태감지 --> 업그레이드 : profile ✓ manifest ✓

    state Phase1 {
        기초스캔 --> 딥스캔
        딥스캔 --> 프리셋매칭
        프리셋매칭 --> 소크라테스문답
        소크라테스문답 --> 계획제시_승인
    }

    프로필재사용 --> Phase1 : 거부
    프로필재사용 --> 프로필저장 : 수락

    Phase1 --> 프로필저장 : 사용자 승인
    업그레이드 --> 프로필저장 : U1~U2 분석

    프로필저장 --> StopHook_block
    StopHook_block --> Phase2_4

    state Phase2_4 {
        스캐폴딩 --> 검증
        검증 --> 보고
    }

    Phase2_4 --> 매니페스트저장
    매니페스트저장 --> StopHook_allow
    StopHook_allow --> [*]
```

---

## 시나리오별 동작

### 1. 신규 셋업 (가장 일반적)

프로필과 매니페스트가 모두 없는 프로젝트.

```
사용자: "하네스 셋업해줘"
→ 자동 스캔 → 2~4개 질문 → 프로필 승인 → 19개 파일 자동 생성 → 완료
```

사용자가 하는 일은 **(1) 셋업 요청, (2) 질문에 답변, (3) 프로필 승인** 세 가지뿐이다.

### 2. 중단 후 재개

이전 세션에서 프로필까지 저장하고 중단된 경우.

```
사용자: "/harness-setup"
→ "기존 프로필이 발견되었습니다. 사용할까요?" → 수락 → scaffold 자동 실행
```

### 3. 업그레이드

이미 하네스가 완성된 프로젝트를 최신 버전으로 갱신.

```
사용자: "하네스 업그레이드해줘"
→ 현재 버전 ↔ 최신 버전 비교 → 변경된 부분만 갱신
```

### 4. Bootstrap

수동으로 AGENTS.md 등을 만들어둔 프로젝트 (매니페스트 없음).

```
→ 기존 파일 분석 → 프로필 역추론 → 빠진 파일만 보충
```

---

## 생성되는 파일

| 카테고리 | 파일 | 역할 |
|----------|------|------|
| **문서** | `AGENTS.md` | 프로젝트 개요, **명령어(source of truth)**, 아키텍처 링크, 주요 규칙, 문서 맵 (100줄 이내) |
| | `CLAUDE.md` | 에이전트 디스패치, 세션 루틴, 운영 사이클, 금지 사항 (`@AGENTS.md` import) |
| | `ARCHITECTURE.md` | 레이어/슬라이스 규칙, 의존성 방향, 네이밍 규칙 |
| **규칙** | `.claude/rules/session-routine.md` | TDD 오케스트레이션 상세 |
| | `.claude/rules/coding-standards.md` | 코드 규칙 + 검증 레벨 (프로필 기반) |
| | `.claude/rules/git-workflow.md` | Git 커밋/브랜치 규칙 + 자동 커밋 정책 |
| **에이전트** | `agents/architect.md` | Pre-Red: 설계 + 테스트 계획 |
| | `agents/test-engineer.md` | Red: 테스트 작성 |
| | `agents/implementer.md` | Green: 구현 |
| | `agents/reviewer.md` | Post-Green: 코드 리뷰 + 자동 검사 승격 후보 표시 |
| | `agents/simplifier.md` | Refactor: 단순화 |
| | `agents/debugger.md` | On-demand: 디버깅 |
| | `agents/security-reviewer.md` | Post-Green: 보안 리뷰 |
| **추적** | `feature_list.json` | 기능 목록 + 검증 상태 추적 (steps ↔ E2E 1:1) |
| | `claude-progress.txt` | 세션별 작업 기록 + TDD STATE |
| **스크립트** | `init.sh` | 의존성 설치 + 개발 서버 실행 + 준비 확인 |
| | `scripts/structural-test.ts` | 아키텍처 의존성 규칙 자동 검증 (위반 시 exit 1) |
| | `scripts/doc-freshness.ts` | 문서 최신성 검사 |
| | `scripts/harness-check.sh` | 하네스 자가진단 8항목 (⑧ E2E 스캐폴드는 playwright.config.ts 존재 시에만 검사, `npm run harness:check`) |
| **품질** | `docs/QUALITY_SCORE.md` | 6개 카테고리 품질 점수표 |
| | `docs/TECH_DEBT.md` | 기술 부채 추적 (4단계 심각도) + 자동 검사 승격 대기 큐 |
| | `docs/HARNESS_FRICTION.md` | 마찰 로그 (피드백 수집) |
| **기타** | `docs/product-specs/` 외 3개 | 제품 요구사항·설계 결정·실행 계획·참고 자료 디렉토리 |
| | `package.json` | `lint:arch`, `validate`, `doc:check`, `harness:check` 스크립트 추가 |
| | `.harness-manifest.json` | 버전 추적 매니페스트 |

> **옵트인 산출물** (문답에서 동의한 경우만): AGENTS.md "보조 스킬" 섹션(외부 통합 연계), ESLint 보조 규칙(설정 파일에 마커 블록), `test:run` 스크립트(watch 러너 가드), 자동 커밋 정책. 동의하지 않으면 어떤 흔적도 생성되지 않는다.

---

## 지원 아키텍처

| 유형 | 감지 기준 | 검증 내용 |
|------|----------|----------|
| **레이어 기반** (`layer-based`) | types/, lib/, services/, hooks/, components/ 등 | 레이어 의존성 방향 |
| **FSD** (`fsd`) | app/, pages/, widgets/, features/, entities/, shared/ | 레이어 + cross-slice + public API |
| **도메인 기반** (`domain-based`) | 도메인명 폴더 아래 components, hooks 등 | 도메인 간 직접 import 금지 + 공유→도메인 역방향 금지 |
| **자유 구조** (`custom`) | 위 패턴에 해당 안 됨 | 프로필에서 기계 검사 가능한 규칙만 (동적 생성) |

---

## 프리셋 시스템

프리셋은 특정 스택+아키텍처 조합의 기본 프로필이다. `presets/` 폴더에 JSON으로 정의한다.

### 내장 프리셋

| 프리셋 | 스택 | 아키텍처 |
|--------|------|---------|
| `react-next` | React 19 + Next.js 15 (App Router) | layer-based 8레이어 (types→…→app) |
| `react-router-fsd` | React + React Router v7 | FSD 6레이어 (shared→…→app) |
| `react-vite` | React + Vite (SPA) | layer-based 7레이어 |
| `express-api` | Express + TypeScript (Node 백엔드) | layer-based 8레이어 (routes→controllers→services→models) |

### 매칭 로직

1. `detection.required` 패키지 전부 존재하는지 확인
2. `detection.exclude` 패키지가 존재하면 후보에서 제외 (범용 required의 오매칭 방지)
3. `detection.versionConstraints`로 버전 범위 체크 (있을 경우)
4. `architecture.type`이 딥스캔 결과와 일치하는지 확인
5. 여러 후보 → optional 매칭 수 → required 수 → 사용자 선택

### 커스텀 프리셋 추가

`presets/` 폴더에 JSON 파일을 만들면 자동으로 매칭 대상에 포함된다.
필수 필드: `name`, `displayName`, `detection.required`, `architecture.type`, `architecture.layers`, `scripts.lint:arch`, `devServer`, `pathAlias`, `srcRoot`.
기존 프리셋을 복사하여 수정하는 것이 가장 빠르다.

---

## 컴패니언 스킬

`install.sh`가 아래 스킬을 `~/.claude/skills/`에 글로벌 링크하여 자연어로 바로 호출할 수 있다.

| 스킬 | 트리거 | 역할 |
|------|--------|------|
| **harness-cleanup** | "하네스 정리" | 운영 사이클(주간/격주/월간) 실행 — 문서 부식·QUALITY_SCORE 재측정·TECH_DEBT·승격 큐·passes 재검증. 소스 코드는 수정하지 않고 TDD 사이클에 위임 |
| **harness-feedback** | "하네스 피드백 분석해줘" | HARNESS_FRICTION.md 마찰 로그를 분석해 반복 패턴을 식별하고 이 리포에 개선 Issue 생성 |
| **multi-model-consult** | "멀티모델 자문" / "교차 자문" | Codex·Gemini CLI에 관점을 분담해 자문하고 Claude가 합성(합의/상충/최종방향/액션). 읽기 전용, 하네스 비의존 범용 도구 |

---

## 외부 통합 (옵트인)

셋업 시 외부 보조 스킬이 감지되면 연계 여부를 묻는다 (미감지 시 질문 자체를 생략). 동의하면 AGENTS.md "보조 스킬" 섹션에 호출 안내가 1줄씩 추가된다. 메커니즘 규약: [`references/integrations/_protocol.md`](references/integrations/_protocol.md).

| 통합 | 감지 | 연계 영역 (코어 충돌 영역은 제외) |
|------|------|----------------------------------|
| **superpowers** | 플러그인/스킬 | brainstorming(설계 결정), systematic-debugging(버그 추적), writing-plans(계획 문서) |
| **multiModelConsult** | 컴패니언 + CLI | 복잡한 설계 결정·트레이드오프의 교차 자문 |

> TDD·코드 리뷰·검증·git 워크플로는 항상 하네스 자체 워크플로가 source of truth다.

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

> 설치 후 `install.sh`를 실행하면 `harness-scaffold`와 모든 컴패니언 스킬(cleanup·feedback·multi-model-consult)이 `~/.claude/skills/`에 심볼릭 링크되어 함께 로딩된다 (멱등 — 재실행 안전).
> ```bash
> git clone <repo> ~/.claude/skills/harness-setup && ~/.claude/skills/harness-setup/install.sh
> ```

---

## 디렉토리 구조

```
harness-setup/
├── SKILL.md                          # 분석 스킬 (Phase 1 + Stop hook 오케스트레이션)
├── README.md                         # 이 파일
├── harness-scaffold/
│   └── SKILL.md                      # 스캐폴딩 스킬 (Phase 2~4, 심볼릭 링크로 디스커버리)
├── install.sh                        # 심볼릭 링크 생성 스크립트 (scaffold + 컴패니언 전부)
├── presets/                          # 스택별 프리셋 (4종)
│   ├── react-next.json               # React + Next.js (App Router, layer-based)
│   ├── react-router-fsd.json         # React Router v7 + FSD
│   ├── react-vite.json               # React + Vite SPA (layer-based)
│   └── express-api.json              # Express + TypeScript API (layer-based)
├── templates/
│   ├── agents/                       # TDD subagent 정의 템플릿 (7개)
│   ├── rules/                        # .claude/rules/ 템플릿 (session-routine, coding-standards, git-workflow)
│   ├── structural-test-layer.ts      # 레이어 기반 아키텍처 검증 템플릿
│   ├── structural-test-fsd.ts        # FSD 아키텍처 검증 템플릿
│   ├── structural-test-domain.ts     # 도메인 기반 아키텍처 검증 템플릿
│   ├── harness-check.sh              # 하네스 자가진단 템플릿
│   ├── init.sh                       # 환경 초기화 스크립트 템플릿
│   ├── doc-freshness.ts              # 문서 최신성 검사 스크립트 템플릿
│   ├── QUALITY_SCORE.md              # 품질 점수표 템플릿
│   ├── TECH_DEBT.md                  # 기술 부채 문서 템플릿
│   └── HARNESS_FRICTION.md           # 정적 참조 문서 템플릿 (이벤트 유형/심각도 참조표; 실제 이벤트는 .harness-friction.jsonl 기록)
├── companion-skills/                 # 컴패니언 스킬 (install.sh 글로벌 링크)
│   ├── harness-cleanup/              # 엔트로피 정리 — 운영 사이클 실행
│   ├── harness-feedback/             # 마찰 로그 분석 → GitHub Issue
│   └── multi-model-consult/          # 멀티모델 합성 자문 (codex/gemini + Claude)
├── references/
│   ├── harness-guide.md              # 하네스 엔지니어링 이론 (P1~P10)
│   ├── harness-checklist.md          # 하네스 구성 체크리스트 (생성 하네스 판정 기준)
│   ├── versioning-policy.md          # semver 버전 관리 정책
│   ├── upgrade-system-design.md      # 업그레이드 시스템 설계
│   ├── integrations/                 # 외부 통합 규약 + 매핑 정본
│   │   ├── _protocol.md
│   │   ├── superpowers-mapping.md
│   │   └── multi-model-consult-mapping.md
│   └── project-context.md            # 설계 결정 기록 + 버전 히스토리
├── .claude/                          # 이 리포 자체의 개발 환경 (커맨드/규칙/설정)
└── .tracking/
    ├── CHANGELOG.md                  # 변경 이력
    ├── TODO.md                       # 작업 추적
    └── HANDOFF.md                    # 세션 간 컨텍스트 전달
```

### 파일별 역할

| 파일 | 용도 | 누가 읽는가 |
|------|------|------------|
| `SKILL.md` | Phase 1 동작 사양 + Stop hook 오케스트레이션 | Claude Code (스킬 실행 시) |
| `harness-scaffold/SKILL.md` | Phase 2~4 동작 사양 (파일 생성 + 검증) | Claude Code (자동 체이닝 시) |
| `presets/*.json` | 스택별 기본 프로필 | SKILL.md Phase 1 Step 3 |
| `templates/*` | 파일 생성의 기반 템플릿 | harness-scaffold/SKILL.md Phase 2 |
| `references/*.md` | 설계 배경, 이론적 근거 | 개발자 (참고용) |
| `.tracking/*` | 개선 작업 이력 | 개발자 (유지보수 시) |

---

## 주요 설계 결정

### 기존 코드 무수정 원칙
이 스킬은 문서와 설정 파일만 추가한다. 기존 `.ts`, `.tsx`, `.js`, `.css`, `tsconfig.json` 등 소스/설정은 건드리지 않는다. **명시적 예외**(사용자가 문답에서 옵트인한 경우에만): package.json `scripts` 필드 추가, ESLint 설정에 보조 규칙 마커 블록 삽입(파싱 불가 시 권고 스니펫으로 폴백, 설정 JS는 실행하지 않음). tsconfig는 어떤 경우에도 수정하지 않고 검사만 한다.

### 2-스킬 분리
분석(harness-setup)과 생성(harness-scaffold)을 분리하여 각 스킬의 컨텍스트 윈도우를 효율적으로 사용한다. Stop hook이 자동 체이닝을 보장하므로 사용자 경험은 단일 스킬과 동일하다. hook은 프로필의 `approved: true`를 확인한 뒤에만 발동한다.

### 소크라테스 문답
고정된 설문지가 아니라, 스캔 결과에서 불확실한 부분만 골라 질문한다. 이미 코드에서 확인된 것은 묻지 않고, 한 번에 3개 이내만 묻는다. 최대 3라운드 후 미확정 항목은 추론값을 사용한다. 옵트인 항목(ESLint 보조 규칙·외부 통합·자동 커밋)은 감지됐을 때만 묻고, 거부하면 어떤 산출물도 만들지 않는다.

### AGENTS.md vs CLAUDE.md 분리
- **AGENTS.md** = "이 프로젝트는 무엇인가" (맥락) — 프로젝트 개요, **명령어(source of truth)**, 아키텍처 설명, 주요 규칙, 문서 맵
- **CLAUDE.md** = "어떻게 작업할 것인가" (행동) — 에이전트 디스패치, 세션 루틴, 운영 사이클, 금지 사항
- 동일 정보를 중복하지 않는다. CLAUDE.md에서 `@AGENTS.md`로 import. 명령어를 AGENTS.md에 두는 이유는 CLAUDE.md를 읽지 않는 범용 에이전트도 명령을 알 수 있어야 하기 때문이다.

### 프리셋 우선, 문답 보완
프리셋이 매칭되면 초기 프로필로 사용하고, 문답은 미세 조정에만 사용한다. 매칭 안 되면 문답으로 처음부터 구성한다.

### 옵트인 자동 커밋 (1.8.0)
기본은 "커밋 제안만"이다. 원하면 `confirm`(메시지+diff 승인 후 commit+push) 또는 `auto` 모드를 옵트인할 수 있다. 단 위험 작업(`push --force`·`reset --hard`·대규모 변경·의존성)은 어느 모드에서도 항상 사용자 승인을 받는다 — 자동화 대상은 정상 TDD 커밋뿐이다.

### 추측 설계 금지
실제 마찰/데이터가 없는 기능은 만들지 않는다. 외부 통합 규약은 두 선례(superpowers·multi-model-consult)가 확보된 뒤에야 일반화했고, 해시 재현성 같은 개선은 방향만 확정하고 실제 오탐이 누적될 때 구현하기로 둔다.

---

## 남은 작업

상세 현황은 `.tracking/HANDOFF.md`에 기록되어 있다. `.tracking/TODO.md`에서 개별 항목을 추적한다.
