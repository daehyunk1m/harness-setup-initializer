# 하네스 엔지니어링 완전 구축 가이드

> **통합 소스**: Anthropic "Effective Harnesses for Long-Running Agents" + OpenAI "Harness Engineering: Leveraging Codex in an Agent-First World" + 실무 요약 문서
>
> **대상**: React + TypeScript 기반 프론트엔드/풀스택 개발자
>
> **목적**: 에이전트가 안정적으로 작업할 수 있는 개발 운영 체계를 단계적으로 구축하기
>
> **이 문서와 SKILL.md의 관계**: SKILL.md가 스킬 실행 시 사용되는 정규 사양이다. 이 가이드는 이론적 배경과 상세 예시를 담는 참조 문서이다. 두 문서가 충돌하면 SKILL.md가 우선한다.
>
> **참고**: 아래 예시들은 가상의 프로젝트를 기반으로 작성되었다. 실제 스킬 실행 시에는 프로젝트 프로필의 실제 값으로 대체해야 한다.

---

## Part 1. 하네스란 무엇인가

### 정의

하네스(Harness)는 AI 에이전트를 감싸는 **런타임 운영 체계**입니다. 에이전트가 프로젝트를 이해하고, 작업하고, 검증하고, 정리할 수 있도록 돕는 **작업 환경 전체**를 뜻합니다.

말(馬)에 비유하면:
- **말** = AI 모델 (강력하지만 방향을 모름)
- **하네스** = 고삐 + 안장 + 재갈 (방향을 잡아주는 장치)
- **기수** = 인간 엔지니어 (방향을 지시하되 직접 뛰지 않음)

### 왜 지금 중요한가

핵심 통찰은 이것입니다: **같은 모델이라도 하네스에 따라 성능이 극적으로 달라집니다.**

LangChain은 모델을 바꾸지 않고 하네스만 개선해서 Terminal Bench 2.0에서 Top 30 → Top 5로 도약했습니다. OpenAI는 3명의 엔지니어가 5개월 만에 100만 줄의 코드를 직접 한 줄도 작성하지 않고 출시했습니다. Anthropic은 Initializer + Coding Agent 패턴으로 장시간 자율 코딩의 핵심 실패 모드를 해결했습니다.

### 하네스의 3대 기둥 (OpenAI 프레임워크)

| 기둥 | 설명 | 핵심 질문 |
|------|------|-----------|
| **컨텍스트 엔지니어링** | 에이전트가 적시에 올바른 정보를 갖게 함 | "에이전트가 뭘 참고해야 하나?" |
| **아키텍처 제약** | 기계적으로 좋은 코드를 강제함 | "어떤 규칙을 자동으로 검증하나?" |
| **엔트로피 관리** | 코드/문서의 부식을 주기적으로 정리 | "시간이 지나도 품질이 유지되나?" |

### 하네스 없이 발생하는 실패 패턴 (Anthropic 연구)

| 실패 패턴 | 설명 |
|-----------|------|
| **원샷 시도** | 한 번에 모든 걸 구현하려다 컨텍스트 소진, 다음 세션은 반쯤 구현된 상태에서 시작 |
| **조기 완료 선언** | 일부 기능이 완성되자 전체가 끝났다고 판단 |
| **검증 없는 완료 처리** | 유닛 테스트만 통과시키고 E2E 동작을 확인하지 않음 |
| **환경 파악에 시간 낭비** | 매 세션마다 프로젝트 상태를 처음부터 파악해야 함 |

---

## Part 2. 전체 프로세스 리스트

하네스 구축은 다음 10개 프로세스를 순서대로 진행합니다.

```
Phase A: 기반 설계
  ├─ P1. 저장소 뼈대 설계
  ├─ P2. 에이전트 안내 문서 체계 구축
  └─ P3. 아키텍처 레이어 정의

Phase B: 작업 체계 구축
  ├─ P4. 기능 리스트 & 실행 계획 문서 설계
  ├─ P5. Initializer Agent 구성
  └─ P6. Coding Agent 세션 루틴 설계

Phase C: 검증 & 강제
  ├─ P7. 실행-검증 피드백 루프 구축
  └─ P8. 아키텍처 규칙 자동 검사 체계

Phase D: 운영 & 진화
  ├─ P9. 품질 관리 & 기술 부채 체계
  └─ P10. 엔트로피 관리 (정리 루프)
```

---

## Part 3. 스텝 바이 스텝 구축 가이드

---

### P1. 저장소 뼈대 설계

**목표**: 에이전트가 "어디서 무엇을 봐야 하는지" 즉시 파악할 수 있는 구조 만들기

**핵심 원칙** (OpenAI): 에이전트 관점에서 컨텍스트 안에서 접근할 수 없는 정보는 사실상 존재하지 않는 것과 같습니다. Slack 대화, Google Docs, 사람 머릿속 지식은 에이전트에게 보이지 않습니다. **저장소가 유일한 진실의 원천(Single Source of Truth)**이어야 합니다.

**React + TypeScript 프로젝트 기준 디렉토리 구조**:

```
my-project/
├── AGENTS.md                    # 에이전트 입구 문서 (~100줄, 목차 역할)
├── ARCHITECTURE.md              # 시스템 구조 원칙
├── claude-progress.txt          # 세션 간 진행 기록 (Anthropic 패턴)
├── feature_list.json            # 기능 목록 + 상태 추적 (Anthropic 패턴)
├── init.sh                      # 환경 초기화 스크립트
│
├── docs/
│   ├── product-specs/           # 제품 요구사항
│   ├── design-docs/             # 설계 결정 문서
│   ├── exec-plans/              # 실행 계획 (작업 단위별)
│   ├── references/              # 참고 자료
│   ├── QUALITY_SCORE.md         # 품질 평가 기준
│   └── TECH_DEBT.md             # 기술 부채 관리
│
├── src/
│   ├── types/                   # 공유 타입 정의
│   ├── config/                  # 설정 & 상수
│   ├── lib/                     # 순수 유틸리티 (외부 의존 없음)
│   ├── services/                # 비즈니스 로직 & API 통신
│   ├── hooks/                   # React 커스텀 훅
│   ├── components/              # UI 컴포넌트
│   │   ├── ui/                  # 기본 UI 요소 (Button, Input 등)
│   │   └── features/            # 기능별 복합 컴포넌트
│   ├── pages/                   # 라우트별 페이지
│   └── app/                     # 앱 진입점 & 라우팅
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── scripts/
│   ├── structural-test.ts       # 아키텍처 규칙 검증 스크립트
│   └── doc-freshness.ts         # 문서 최신성 검사 스크립트
│
├── .eslintrc.js                 # 린트 규칙 (아키텍처 제약 포함)
├── tsconfig.json
├── package.json
└── .gitignore
```

**실행 명령 통일** (package.json):

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "test": "vitest",
    "test:e2e": "playwright test",
    "lint": "eslint . --ext .ts,.tsx",
    "lint:arch": "ts-node scripts/structural-test.ts",
    "typecheck": "tsc --noEmit",
    "validate": "npm run typecheck && npm run lint && npm run lint:arch && npm run test"
  }
}
```

**체크포인트**: `npm run validate`가 정상 동작하는가?

---

### P2. 에이전트 안내 문서 체계 구축

**목표**: 에이전트가 프로젝트 전체를 빠르게 이해할 수 있는 문서 계층 만들기

**핵심 원칙** (OpenAI): AGENTS.md를 백과사전이 아니라 **목차(Table of Contents)**로 만들어야 합니다. 모든 걸 한 파일에 몰아넣으면 금방 부패하고, 에이전트가 무엇이 최신인지 판단할 수 없습니다.

**AGENTS.md 작성 예시** (~100줄 이내):

```markdown
# AGENTS.md

## 프로젝트 개요
MSO CRM 시스템 - 치과 클리닉 고객 관리 웹앱
스택: React 19 + TypeScript + Next.js 15 (App Router) + Tailwind CSS

## 아키텍처
→ ARCHITECTURE.md 참조

의존성 방향: types → config → lib → services → hooks → components → pages → app
이 방향을 역행하는 import는 금지.

## 현재 상태
→ claude-progress.txt (최근 작업 기록)
→ feature_list.json (기능별 완료 상태)

## 주요 규칙
1. 한 번에 하나의 기능만 구현한다
2. 구현 후 반드시 `npm run validate` 실행
3. feature_list.json의 passes 필드만 수정 (기능 삭제/수정 금지)
4. 매 작업 완료 시 git commit + progress 업데이트

## 문서 맵
| 문서 | 위치 | 용도 |
|------|------|------|
| 제품 요구사항 | docs/product-specs/ | 기능 명세 |
| 설계 문서 | docs/design-docs/ | 기술 결정 기록 |
| 실행 계획 | docs/exec-plans/ | 작업별 계획서 |
| 품질 기준 | docs/QUALITY_SCORE.md | 코드 품질 평가표 |
| 기술 부채 | docs/TECH_DEBT.md | 알려진 문제 & 부채 |

## 테스트
- 유닛: `npm run test`
- E2E: `npm run test:e2e`
- 아키텍처: `npm run lint:arch`

## 개발 서버
→ init.sh 실행 또는 `npm run dev`
→ http://localhost:3000
```

**ARCHITECTURE.md 작성 예시**:

```markdown
# ARCHITECTURE.md

## 레이어 구조

Types → Config → Lib → Services → Hooks → Components → Pages → App

### 규칙
- 각 레이어는 왼쪽 레이어만 import 가능
- components/ui/는 services를 직접 호출하지 않음 (hooks를 통해서만)
- pages/는 비즈니스 로직을 직접 포함하지 않음

### 폴더별 책임
| 폴더 | 책임 | 허용 import |
|------|------|-------------|
| types/ | 공유 타입, enum, interface | 없음 (최하위) |
| config/ | 환경변수, 상수, 설정 | types |
| lib/ | 순수 유틸 함수 | types, config |
| services/ | API 통신, 비즈니스 로직 | types, config, lib |
| hooks/ | React 상태/사이드이펙트 | types, config, lib, services |
| components/ | UI 렌더링 | types, config, hooks |
| pages/ | 라우트 조합 | 모든 레이어 |

### 네이밍 규칙
- 컴포넌트: PascalCase (PatientCard.tsx)
- 훅: camelCase, use 접두사 (usePatientList.ts)
- 서비스: camelCase (patientService.ts)
- 타입: PascalCase, 접미사 Type/Props/State
- 테스트: 원본명.test.ts(x)
```

**체크포인트**: 새로운 사람(또는 에이전트)이 AGENTS.md만 읽고 프로젝트를 파악할 수 있는가?

---

### P3. 아키텍처 레이어 정의

**목표**: 에이전트가 잘못된 의존성을 만들 수 없도록 경계를 설정하기

**핵심 원칙** (OpenAI): 솔루션 공간을 제약하면 에이전트가 오히려 더 생산적이 됩니다. 무엇이든 가능할 때 에이전트는 토큰을 낭비하며 막다른 길을 탐색합니다. 명확한 경계가 있으면 올바른 해결책에 더 빨리 수렴합니다.

**의존성 레이어** (React + TS 기준):

```
Types → Config → Lib → Services → Hooks → Components → Pages → App
  ↑                                                              ↓
  └──────────── 의존성은 항상 왼쪽으로만 ─────────────────────────┘
```

**TypeScript path alias로 명시화** (tsconfig.json):

```json
{
  "compilerOptions": {
    "paths": {
      "@/types/*": ["./src/types/*"],
      "@/config/*": ["./src/config/*"],
      "@/lib/*": ["./src/lib/*"],
      "@/services/*": ["./src/services/*"],
      "@/hooks/*": ["./src/hooks/*"],
      "@/components/*": ["./src/components/*"],
      "@/pages/*": ["./src/pages/*"]
    }
  }
}
```

**체크포인트**: 레이어 규칙이 문서화되었고, 위반 시 감지할 방법이 있는가?

---

### P4. 기능 리스트 & 실행 계획 문서 설계

**목표**: 에이전트가 "무엇을 해야 하는지"와 "어디까지 했는지"를 기계적으로 판단할 수 있게 하기

**핵심 원칙** (Anthropic): 초기화 에이전트가 사용자의 프롬프트를 확장한 **포괄적인 기능 목록**을 만들고, 모든 기능을 "failing"으로 표시합니다. 이후 코딩 에이전트는 이 목록을 보고 다음에 무엇을 할지 결정합니다. JSON을 사용하면 에이전트가 부적절하게 내용을 수정할 가능성이 줄어듭니다.

**feature_list.json 구조**:

```json
[
  {
    "id": "F001",
    "category": "auth",
    "priority": 1,
    "description": "사용자가 이메일/비밀번호로 로그인하면 대시보드로 이동한다",
    "steps": [
      "로그인 페이지로 이동",
      "이메일과 비밀번호 입력",
      "로그인 버튼 클릭",
      "대시보드 페이지가 표시되는지 확인",
      "사용자 이름이 헤더에 표시되는지 확인"
    ],
    "passes": false,
    "last_session": null,
    "notes": ""
  },
  {
    "id": "F002",
    "category": "auth",
    "priority": 2,
    "description": "잘못된 비밀번호로 로그인 시 에러 메시지가 표시된다",
    "steps": [
      "로그인 페이지로 이동",
      "이메일 입력, 잘못된 비밀번호 입력",
      "로그인 버튼 클릭",
      "에러 메시지가 표시되는지 확인",
      "입력 필드가 초기화되지 않는지 확인"
    ],
    "passes": false,
    "last_session": null,
    "notes": ""
  }
]
```

**실행 계획 문서** (docs/exec-plans/EP001-login.md):

```markdown
# EP001: 로그인 기능 구현

## 작업 목표
이메일/비밀번호 기반 로그인 기능 구현

## 범위
- 로그인 폼 UI (LoginForm 컴포넌트)
- 인증 서비스 (authService.ts)
- 인증 상태 훅 (useAuth.ts)
- 로그인 페이지 조합 (pages/login)

## 비범위
- 회원가입, 비밀번호 찾기
- 소셜 로그인
- 세션 갱신

## 관련 기능
- feature_list.json: F001, F002

## 완료 조건
- [ ] LoginForm 컴포넌트 렌더링
- [ ] 유효성 검사 동작
- [ ] 성공 시 대시보드 리다이렉트
- [ ] 실패 시 에러 메시지 표시
- [ ] 유닛 테스트 통과
- [ ] E2E 테스트 통과

## 검증 방법
1. `npm run dev`로 서버 실행
2. /login 페이지 접속
3. 올바른 인증정보로 로그인 → 대시보드 이동 확인
4. 잘못된 인증정보로 로그인 → 에러 표시 확인
5. `npm run test` 통과
6. `npm run lint:arch` 통과
```

**체크포인트**: 에이전트가 feature_list.json을 읽고 다음 작업을 스스로 선택할 수 있는가?

---

### P5. Initializer Agent 구성

**목표**: 첫 세션에서 프로젝트 환경을 완전히 셋업하기

**핵심 원칙** (Anthropic): 첫 번째 컨텍스트 윈도우에는 "다른 프롬프트"를 사용합니다. 이 초기화 에이전트가 이후 코딩 에이전트에게 필요한 모든 컨텍스트를 갖춘 환경을 셋업합니다.

**Initializer Agent가 수행할 작업 체크리스트**:

```markdown
# Initializer Agent 프롬프트 핵심 내용

당신은 프로젝트 초기화 에이전트입니다.
사용자의 요구사항을 기반으로 다음을 순서대로 수행하세요:

## 1. 프로젝트 스캐폴딩
- Next.js + TypeScript 프로젝트 생성
- 디렉토리 구조 생성 (ARCHITECTURE.md의 레이어 구조 준수)
- 기본 설정 파일 구성 (tsconfig, eslint, prettier, tailwind 등)

## 2. 핵심 문서 작성
- AGENTS.md: 프로젝트 개요, 규칙, 문서 맵 (~100줄)
- ARCHITECTURE.md: 레이어 구조, 의존성 규칙, 네이밍 규칙
- docs/product-specs/PRD.md: 제품 요구사항

## 3. 기능 목록 생성
- feature_list.json 작성
- 사용자의 요구사항을 세분화하여 최소 50개 이상의 검증 가능한 기능으로 분해
- 모든 기능의 passes를 false로 설정
- 카테고리별로 우선순위 부여

## 4. 초기화 스크립트
- init.sh 작성 (의존성 설치, 개발 서버 실행, 기본 동작 확인)
- package.json scripts 통일

## 5. 검증 체계 기초
- 아키텍처 검증 스크립트 (scripts/structural-test.ts)
- 기본 테스트 환경 구성 (vitest + playwright)
- CI 기본 설정

## 6. Git 초기화
- .gitignore 설정
- 초기 커밋: "Initial project scaffold with harness structure"
- claude-progress.txt 작성: 초기화 내용 기록

## 절대 규칙
- 기능 구현은 하지 않는다 (셋업만 한다)
- feature_list.json의 기능은 삭제하거나 편집하지 않는다
- 모든 문서는 에이전트가 읽기 쉬운 형태로 작성한다
```

**체크포인트**: init.sh를 실행하면 개발 서버가 뜨고, 기본 페이지가 렌더링되는가?

---

### P6. Coding Agent 세션 루틴 설계

**목표**: 매 세션마다 에이전트가 일관된 방식으로 작업을 시작하고 마무리하게 하기

**핵심 원칙** (Anthropic): 각 코딩 에이전트는 상황 파악을 위한 일련의 단계를 거치도록 합니다. 이 접근은 에이전트가 한 번에 너무 많이 하려는 경향을 해결하는 데 핵심이었습니다.

**세션 시작 루틴**:

```markdown
# Coding Agent 프롬프트 핵심 내용

당신은 코딩 에이전트입니다.
매 세션의 시작과 종료에서 다음 절차를 따르세요.

## 세션 시작 절차 (매번 반드시 실행)

### Step 1: 현재 위치 확인
pwd

### Step 2: 진행 상황 파악
- claude-progress.txt 읽기
- git log --oneline -20 확인
- feature_list.json에서 passes: false인 항목 확인

### Step 3: 환경 확인
- init.sh 또는 npm run dev로 개발 서버 실행
- 기본 동작 확인 (메인 페이지 렌더링 등)
- 기존 기능이 깨지지 않았는지 빠르게 체크

### Step 4: 작업 선택
- feature_list.json에서 가장 높은 우선순위의 미완료 기능 선택
- 해당 기능의 실행 계획 문서가 있으면 참조
- 한 번에 하나의 기능만 작업

## 구현 규칙
- ARCHITECTURE.md의 레이어 규칙 준수
- 구현 후 반드시 npm run validate 실행
- 테스트를 함께 작성
- E2E로 실제 동작 검증

## 세션 종료 절차 (매번 반드시 실행)

### Step 1: 검증
- npm run validate 실행 (typecheck + lint + lint:arch + test)
- 구현한 기능을 브라우저/테스트로 직접 확인

### Step 2: 상태 업데이트
- feature_list.json의 passes 필드 업데이트 (검증된 기능만 true로)
- claude-progress.txt에 이번 세션 요약 추가

### Step 3: 커밋
- git add & commit (설명적인 커밋 메시지)
- 예: "feat(auth): implement login form with validation - F001"

## 절대 규칙
- feature_list.json에서 기능을 삭제하거나 설명을 수정하지 않는다
- passes 필드는 실제 검증 후에만 true로 변경한다
- 세션 종료 시 코드는 반드시 빌드 가능한 상태여야 한다
- 버그를 발견하면 새 기능보다 버그 수정을 우선한다
```

**세션 흐름 다이어그램**:

```
세션 시작
  │
  ├── 1. pwd / progress 읽기 / git log 확인
  ├── 2. 개발 서버 실행 & 기본 동작 확인
  ├── 3. 기존 버그 발견? → Yes → 버그 수정 우선
  │                       → No  → 다음 단계
  ├── 4. feature_list.json에서 다음 기능 선택
  ├── 5. 실행 계획 문서 참조 (있으면)
  │
  ├── [구현 루프]
  │     ├── 코드 작성
  │     ├── npm run validate
  │     ├── 실패? → 수정 → 재검증
  │     └── 성공? → 다음 단계
  │
  ├── 6. E2E / 브라우저 검증
  ├── 7. feature_list.json 업데이트
  ├── 8. claude-progress.txt 업데이트
  └── 9. git commit
```

**체크포인트**: 에이전트가 아무 컨텍스트 없이 시작해도 5분 내에 다음 작업을 파악하고 시작할 수 있는가?

---

### P7. 실행-검증 피드백 루프 구축

**목표**: 에이전트가 코드를 작성한 뒤 스스로 결과를 확인하고 수정할 수 있게 하기

**핵심 원칙** (Anthropic): Claude에게 브라우저 자동화 같은 테스트 도구를 제공하면 성능이 극적으로 향상됩니다. 코드만 봐서는 발견할 수 없었던 버그를 잡을 수 있습니다.

**핵심 원칙** (OpenAI): 에이전트는 특정 피드백 루프 안에서 작동합니다 - "컨텍스트 수집 → 행동 → 검증 → 반복". 이 루프가 에이전트 설계의 유용한 사고 모델입니다.

**검증 체계 구성**:

```
구현
  │
  ├── Level 1: 정적 검증 (즉시)
  │     ├── TypeScript 타입 체크 (tsc --noEmit)
  │     ├── ESLint 규칙 검사
  │     └── 아키텍처 레이어 검증
  │
  ├── Level 2: 유닛 테스트 (수초)
  │     ├── 컴포넌트 렌더링 테스트
  │     ├── 훅 동작 테스트
  │     └── 서비스 로직 테스트
  │
  ├── Level 3: 통합 테스트 (수십초)
  │     ├── API 연동 테스트 (MSW mock)
  │     └── 페이지 단위 테스트
  │
  └── Level 4: E2E 테스트 (수분)
        ├── Playwright 브라우저 자동화
        ├── 실제 사용자 시나리오 재현
        └── 스크린샷 비교 (시각적 검증)
```

**Playwright E2E 예시** (tests/e2e/login.spec.ts):

```typescript
import { test, expect } from '@playwright/test';

test('F001: 올바른 인증정보로 로그인 시 대시보드 이동', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'test@example.com');
  await page.fill('[data-testid="password"]', 'password123');
  await page.click('[data-testid="login-button"]');
  
  await expect(page).toHaveURL('/dashboard');
  await expect(page.locator('[data-testid="user-name"]')).toBeVisible();
});

test('F002: 잘못된 비밀번호로 로그인 시 에러 표시', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'test@example.com');
  await page.fill('[data-testid="password"]', 'wrong');
  await page.click('[data-testid="login-button"]');
  
  await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
  await expect(page).toHaveURL('/login');
});
```

**init.sh 예시**:

```bash
#!/bin/bash
set -e

echo "=== 환경 초기화 ==="

# 의존성 설치
if [ ! -d "node_modules" ]; then
  echo "의존성 설치 중..."
  npm install
fi

# 개발 서버 실행 (백그라운드)
echo "개발 서버 시작..."
npm run dev &
DEV_PID=$!

# 서버 준비 대기
echo "서버 준비 대기 중..."
sleep 5

# 기본 동작 확인
echo "기본 동작 확인..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200" && \
  echo "✅ 서버 정상 동작" || \
  echo "❌ 서버 응답 없음"

echo "=== 초기화 완료 (PID: $DEV_PID) ==="
```

**체크포인트**: `npm run validate` 한 줄로 모든 레벨의 검증이 실행되는가?

---

### P8. 아키텍처 규칙 자동 검사 체계

**목표**: 리뷰에서 반복되는 말을 코드로 된 규칙으로 승격시키기

**핵심 원칙** (OpenAI): 의존성은 Types → Config → Repo → Service → Runtime → UI 순서로만 흐릅니다. 이것은 제안이 아니라 구조 테스트와 CI로 강제됩니다.

**핵심 원칙** (요약 문서): 리뷰에서 반복되는 말을 규칙으로 승격한다. 문서에만 있는 규칙은 쉽게 무너집니다.

**구조 테스트 스크립트** (scripts/structural-test.ts):

```typescript
import * as fs from 'fs';
import * as path from 'path';

// 레이어 정의: 각 레이어가 import할 수 있는 레이어 목록
const LAYER_RULES: Record<string, string[]> = {
  'types':      [],
  'config':     ['types'],
  'lib':        ['types', 'config'],
  'services':   ['types', 'config', 'lib'],
  'hooks':      ['types', 'config', 'lib', 'services'],
  'components': ['types', 'config', 'hooks', 'lib'],
  'pages':      ['types', 'config', 'lib', 'services', 'hooks', 'components'],
  'app':        ['types', 'config', 'lib', 'services', 'hooks', 'components', 'pages'],
};

interface Violation {
  file: string;
  line: number;
  importedLayer: string;
  currentLayer: string;
  importStatement: string;
}

function findViolations(srcDir: string): Violation[] {
  const violations: Violation[] = [];
  
  for (const [layer, allowed] of Object.entries(LAYER_RULES)) {
    const layerDir = path.join(srcDir, layer);
    if (!fs.existsSync(layerDir)) continue;
    
    const files = getFilesRecursive(layerDir);
    
    for (const file of files) {
      const content = fs.readFileSync(file, 'utf-8');
      const lines = content.split('\n');
      
      lines.forEach((line, idx) => {
        const importMatch = line.match(/from\s+['"]@\/(\w+)/);
        if (!importMatch) return;
        
        const importedLayer = importMatch[1];
        if (importedLayer !== layer && !allowed.includes(importedLayer)) {
          violations.push({
            file: path.relative(srcDir, file),
            line: idx + 1,
            importedLayer,
            currentLayer: layer,
            importStatement: line.trim(),
          });
        }
      });
    }
  }
  
  return violations;
}

// 실행
const violations = findViolations('./src');

if (violations.length > 0) {
  console.error('❌ 아키텍처 위반 발견:\n');
  violations.forEach(v => {
    console.error(`  ${v.file}:${v.line}`);
    console.error(`    ${v.currentLayer} → ${v.importedLayer} (금지)`);
    console.error(`    ${v.importStatement}\n`);
  });
  process.exit(1);
} else {
  console.log('✅ 아키텍처 규칙 검증 통과');
}
```

**ESLint 추가 규칙** (.eslintrc.js):

```javascript
module.exports = {
  rules: {
    // components/ui/에서 services 직접 import 금지
    'no-restricted-imports': ['error', {
      patterns: [
        {
          group: ['@/services/*'],
          message: 'UI 컴포넌트는 services를 직접 import할 수 없습니다. hooks를 통해 접근하세요.'
        }
      ]
    }],
    // 파일 크기 제한 (에이전트 친화적)
    'max-lines': ['warn', { max: 300, skipBlankLines: true, skipComments: true }],
  }
};
```

**자동화 진행 로드맵**:

| 단계 | 자동화 대상 | 도구 |
|------|------------|------|
| 즉시 | 레이어 간 import 방향 | structural-test.ts |
| 즉시 | 코드 스타일 / 포맷팅 | ESLint + Prettier |
| 1주차 | 네이밍 규칙 | ESLint custom rule |
| 2주차 | 테스트 필수 조건 (새 파일에 테스트 동반) | CI check |
| 3주차 | 파일 크기 제한 | ESLint max-lines |
| 4주차 | 컴포넌트 props 타입 필수 | TypeScript strict |

**체크포인트**: `npm run lint:arch`가 의존성 역전을 감지하고 빌드를 실패시키는가?

---

### P9. 품질 관리 & 기술 부채 체계

**목표**: "무엇이 좋은 결과인지"를 명확히 정의하여 에이전트가 품질 기준을 고려하며 작업하게 하기

**핵심 원칙** (요약 문서): acceptance test, 회귀 테스트, 품질 점수표, 기술 부채 문서가 있어야 에이전트가 단순 구현을 넘어 품질 기준을 고려할 수 있습니다.

**docs/QUALITY_SCORE.md**:

```markdown
# 품질 점수표

## 현재 점수: 72/100

### 카테고리별 점수

| 카테고리 | 점수 | 기준 |
|---------|------|------|
| 타입 안전성 | 18/20 | strict mode, any 사용 횟수 |
| 테스트 커버리지 | 15/20 | 목표 80%, 현재 75% |
| 아키텍처 준수 | 20/20 | 레이어 위반 0건 |
| 접근성 | 8/15 | aria-label, keyboard nav |
| 성능 | 11/15 | LCP < 2.5s, bundle size |
| 문서 최신성 | 10/10 | 마지막 검증: 2026-04-01 |

### Known Issues
- [ ] #12: PatientList 무한 스크롤 메모리 누수
- [ ] #15: 다크모드 전환 시 차트 색상 미적용
```

**docs/TECH_DEBT.md**:

```markdown
# 기술 부채 관리

## 긴급 (이번 스프린트)
- authService에 하드코딩된 토큰 만료 시간 → config로 이동

## 높음 (다음 스프린트)
- PatientCard 컴포넌트 300줄 초과 → 분리 필요
- API 에러 핸들링 일관성 부족 → 공통 에러 핸들러 도입

## 보통 (백로그)
- CSS-in-JS → Tailwind 마이그레이션 (일부 레거시)
- 테스트 더블 방식 통일 (MSW vs jest.mock 혼재)

## 리팩터링 대상
| 파일 | 문제 | 우선순위 |
|------|------|---------|
| services/patientService.ts | 함수 10개, 단일 책임 위반 | 높음 |
| components/features/Dashboard.tsx | 비즈니스 로직 직접 포함 | 높음 |
| hooks/usePatientForm.ts | 상태 8개, 분리 필요 | 보통 |
```

**체크포인트**: 에이전트가 QUALITY_SCORE.md를 참조해서 "이번에 테스트 커버리지를 올려야겠다"는 판단을 할 수 있는가?

---

### P10. 엔트로피 관리 (정리 루프)

**목표**: 시간이 지나도 코드와 문서의 품질이 부식되지 않게 주기적으로 정리하기

**핵심 원칙** (OpenAI): 주기적 정리 에이전트가 문서의 일관성을 검증하고, 아키텍처 위반을 찾고, 패턴 이탈을 수정하는 cleanup PR을 자동으로 생성합니다.

**핵심 원칙** (요약 문서): 하네스는 한 번 만드는 설정이 아니라 지속적으로 관리하는 운영 체계입니다.

**정리 체크리스트 (주간)**:

```markdown
## 주간 정리 체크리스트

### 문서
- [ ] AGENTS.md가 현재 구조와 일치하는가?
- [ ] ARCHITECTURE.md의 레이어 규칙이 최신인가?
- [ ] feature_list.json의 passes 상태가 실제와 일치하는가?
- [ ] QUALITY_SCORE.md 점수를 재측정했는가?

### 코드
- [ ] npm run lint:arch 위반 0건인가?
- [ ] 300줄 초과 파일이 새로 생겼는가?
- [ ] any 타입 사용이 늘어났는가?
- [ ] 사용하지 않는 의존성이 있는가?

### 테스트
- [ ] 테스트 커버리지가 목표 이상인가?
- [ ] 깨진 테스트가 있는가?
- [ ] E2E 테스트가 모두 통과하는가?

### 기술 부채
- [ ] TECH_DEBT.md에 새 항목을 추가했는가?
- [ ] 긴급 부채를 해결했는가?
```

**문서 최신성 검사 스크립트** (scripts/doc-freshness.ts):

```typescript
import * as fs from 'fs';
import * as path from 'path';

const DOCS_TO_CHECK = [
  'AGENTS.md',
  'ARCHITECTURE.md',
  'docs/QUALITY_SCORE.md',
  'docs/TECH_DEBT.md',
];

const STALE_DAYS = 14; // 14일 이상 미수정 시 경고
const now = Date.now();

for (const doc of DOCS_TO_CHECK) {
  if (!fs.existsSync(doc)) {
    console.warn(`⚠️  누락: ${doc}`);
    continue;
  }
  
  const stat = fs.statSync(doc);
  const daysSinceModified = Math.floor((now - stat.mtimeMs) / (1000 * 60 * 60 * 24));
  
  if (daysSinceModified > STALE_DAYS) {
    console.warn(`⚠️  오래됨 (${daysSinceModified}일): ${doc}`);
  } else {
    console.log(`✅ 최신 (${daysSinceModified}일): ${doc}`);
  }
}
```

**운영 사이클**:

```
일간: npm run validate (자동 CI)
주간: 문서 최신성 검사 + QUALITY_SCORE 업데이트
격주: TECH_DEBT 검토 + 리팩터링 세션
월간: AGENTS.md / ARCHITECTURE.md 전면 검토
```

**체크포인트**: 2주 뒤에도 에이전트가 처음과 같은 품질로 작업할 수 있는가?

---

## Part 4. 전체 요약 — 한 눈에 보기

### 프로세스 체크리스트

| # | 프로세스 | 산출물 | 소요 시간 |
|---|---------|--------|----------|
| P1 | 저장소 뼈대 설계 | 디렉토리 구조 + package.json scripts | 1-2시간 |
| P2 | 안내 문서 체계 | AGENTS.md + ARCHITECTURE.md + docs/ | 2-3시간 |
| P3 | 아키텍처 레이어 정의 | 의존성 규칙 + tsconfig paths | 1시간 |
| P4 | 기능 리스트 & 실행 계획 | feature_list.json + exec-plans/ | 2-4시간 |
| P5 | Initializer Agent | 초기화 프롬프트 + init.sh | 1-2시간 |
| P6 | Coding Agent 루틴 | 세션 시작/종료 프롬프트 + progress 파일 | 1-2시간 |
| P7 | 실행-검증 루프 | 테스트 환경 + E2E 설정 + validate 명령 | 3-4시간 |
| P8 | 아키텍처 자동 검사 | structural-test.ts + ESLint rules | 2-3시간 |
| P9 | 품질/부채 관리 | QUALITY_SCORE.md + TECH_DEBT.md | 1-2시간 |
| P10 | 엔트로피 관리 | 정리 체크리스트 + 문서 검사 스크립트 | 1-2시간 |

**총 예상: 약 2-3일 (기초 셋업) → 이후 점진적 강화**

### 6대 핵심 원칙

| # | 원칙 | 출처 |
|---|------|------|
| 1 | 긴 프롬프트보다 좋은 저장소 구조가 더 중요하다 | OpenAI |
| 2 | 한 번에 하나의 기능만, 점진적으로 | Anthropic |
| 3 | 에이전트가 접근할 수 없는 정보는 없는 정보다 | OpenAI |
| 4 | 리뷰에서 반복되는 말은 자동 검사로 승격한다 | OpenAI + 요약 |
| 5 | 에이전트가 스스로 검증할 수 있어야 한다 | Anthropic |
| 6 | 하네스는 만드는 것이 아니라 운영하는 것이다 | 공통 |

### 참고 자료

- Anthropic 공식: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic 퀵스타트 코드: https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding
- OpenAI 원문: https://openai.com/index/harness-engineering/
- Claude 4 프롬프팅 가이드: https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices
