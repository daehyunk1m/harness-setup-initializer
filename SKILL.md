---
name: harness-setup
description: "하네스가 없는 프로젝트에 에이전트 작업 환경(하네스)을 셋업하는 스킬. 소스 코드를 분석하고, 사용자와 문답을 통해 프로젝트에 맞는 하네스를 구성한다. 기존 소스 코드는 수정하지 않으며, 문서와 설정 파일만 추가한다. 사용자가 하네스 셋업, harness setup, 에이전트 환경 구축, AGENTS.md 생성, 에이전트가 작업할 수 있게 환경 잡아줘, 프로젝트에 하네스 적용 등을 언급할 때 이 스킬을 사용한다."
context: fork
model: sonnet
---

# Harness Setup Skill

## 1. 개요

이 스킬은 하네스가 없는 프로젝트에 **에이전트 작업 환경(하네스)**을 셋업한다.

하네스란 에이전트가 프로젝트를 이해하고, 작업하고, 검증하고, 정리할 수 있도록 돕는 **작업 환경 전체**이다.

### 이 스킬이 하는 일
- 프로젝트 소스 코드와 구조를 분석하여 아키텍처를 파악한다
- 파악이 불확실한 부분은 사용자에게 문답으로 확인한다
- 프로젝트에 맞는 하네스 파일(문서, 설정, 검증 스크립트)을 생성한다
- package.json에 validate 명령을 추가한다

### 이 스킬이 하지 않는 일
- 기존 소스 코드를 수정하거나 이동하지 않는다
- 기존 폴더 구조를 재배치하지 않는다
- 앱 기능을 구현하지 않는다
- 기존 설정 파일(eslint, tsconfig 등)을 덮어쓰지 않는다

### 지원 범위
- **Node.js / TypeScript 프로젝트** (package.json 필수)
- Python, Go, Rust 등 다른 생태계는 현재 지원하지 않는다

---

## 2. 트리거 조건

다음 상황에서 이 스킬을 실행한다:

- "하네스 셋업", "harness setup", "에이전트 환경 구축" 등을 요청할 때
- "이 프로젝트에 AGENTS.md를 만들어줘" 등 하네스 구성 요소를 요청할 때
- "에이전트가 작업할 수 있게 환경을 잡아줘" 등을 요청할 때

---

## 3. 실행 흐름

```
Phase 1: 스캔 & 분석
  ├── Step 1: 기초 스캔 (자동)
  ├── Step 2: 소스 코드 딥스캔 (자동)
  ├── Step 3: 프리셋 매칭 (자동)
  ├── Step 4: 소크라테스 문답 (대화)
  └── Step 5: 계획 제시 & 승인 (대화)
         ↓
[사용자 승인]
         ↓
Phase 2: 스캐폴딩 (승인 후 실행)
         ↓
Phase 3: 검증 (자동)
         ↓
Phase 4: 보고 (결과 요약)
```

---

## 4. Phase 1: 스캔 & 분석

### 목표
프로젝트를 분석하고, 사용자와 문답을 통해 하네스 구성에 필요한 **프로젝트 프로필**을 완성한다.

프로젝트 프로필이란 이 프로젝트의 스택, 아키텍처, 의존성 규칙, 네이밍 규칙, 개발/테스트 환경을 기술한 데이터이다. 프리셋이 매칭되면 프리셋이 초기 프로필이 되고, 매칭되지 않으면 스캔 + 문답으로 프로필을 처음부터 구성한다.

---

### Step 1: 기초 스캔 (자동)

프로젝트의 외형적 정보를 수집한다.

#### 1.1 프로젝트 루트 확인
```bash
pwd
ls -la
```
확인 항목:
- package.json 존재 여부 (없으면 중단, 사용자에게 알림)
- 소스 디렉토리 존재 여부 (src/, app/, lib/ 등)
- 기존 하네스 파일 존재 여부 (AGENTS.md, CLAUDE.md, .cursorrules 등)

#### 1.2 스택 감지
```bash
cat package.json
```
감지 항목:
- `dependencies`에서: 주요 프레임워크 및 라이브러리
- `devDependencies`에서: TypeScript, 린트, 포맷터, 테스트 도구
- `scripts`에서: dev, build, test, lint 명령과 그 내용
- 패키지 매니저: package-lock.json / yarn.lock / pnpm-lock.yaml 존재 여부

#### 1.3 디렉토리 구조 매핑
```bash
find . -type d -maxdepth 4 -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.next/*' -not -path '*/dist/*' -not -path '*/.turbo/*' | sort
```
매핑 항목:
- 소스 루트 위치 (src/, app/ 등)
- 최상위 폴더 이름 목록
- 폴더 깊이와 구조 패턴

#### 1.4 기존 설정 파일 파악
```bash
ls -la .eslintrc* eslint.config.* .prettierrc* tsconfig.json tailwind.config.* vite.config.* vitest.config.* playwright.config.* jest.config.* next.config.* 2>/dev/null
```
확인 항목:
- 어떤 설정이 이미 있는지 (충돌 방지용)
- tsconfig.json의 paths 설정 유무와 alias 형태
- 테스트 프레임워크 종류

#### 1.5 기존 하네스 흔적 확인
```bash
ls -la AGENTS.md CLAUDE.md claude-progress.txt feature_list.json .cursorrules docs/ 2>/dev/null
```
이미 있는 항목은 덮어쓰지 않고 스킵 대상으로 표시한다.

---

### Step 2: 소스 코드 딥스캔 (자동)

소스 코드를 직접 읽어서 **실제 아키텍처 패턴**을 파악한다.

#### 2.1 진입점 파일 확인
프레임워크에 따라 진입점을 찾는다:
```bash
# 가능한 진입점 파일들을 탐색
find . -maxdepth 3 -name "layout.tsx" -o -name "layout.ts" -o -name "_app.tsx" -o -name "main.tsx" -o -name "main.ts" -o -name "index.tsx" -o -name "root.tsx" -o -name "entry.client.tsx" 2>/dev/null | head -10
```
진입점을 찾으면 해당 파일을 읽어 앱의 구조를 파악한다.

#### 2.2 import 패턴 분석
```bash
# 소스 파일들의 import 문을 수집하여 의존성 패턴을 파악한다
# from '...' 패턴으로 검색하여 re-export(export { x } from '...')도 포함한다
grep -rn "from\s\+['\"]" --include="*.ts" --include="*.tsx" src/ 2>/dev/null | head -80
```
분석 항목:
- path alias 형태 (@/, ~/, #/ 등)
- 어떤 폴더끼리 서로 import하는지 (의존성 방향)
- 외부 라이브러리 사용 패턴 (상태관리, API 클라이언트 등)

#### 2.3 폴더별 역할 추론
각 최상위 폴더에서 대표 파일 1~2개를 읽어 역할을 추론한다:
```bash
# 각 폴더의 파일 목록과 대표 파일 내용 확인
for dir in src/*/; do
  echo "=== $dir ==="
  ls "$dir" | head -5
  # 첫 번째 .ts 또는 .tsx 파일 내용 확인
  head -30 "$dir"*.{ts,tsx} 2>/dev/null | head -30
done
```
추론 항목:
- 이 폴더는 어떤 종류의 코드를 담고 있는가 (UI, 로직, 타입, 유틸 등)
- 아키텍처 패턴은 무엇인가 (레이어 기반, FSD, 도메인 기반, 자유 구조 등)

#### 2.4 아키텍처 패턴 분류
딥스캔 결과를 종합하여 아키텍처 패턴을 분류한다:

| 패턴 | type 값 | 판별 기준 |
|------|---------|----------|
| **레이어 기반** | `layer-based` | types/, lib/, services/, hooks/, components/ 등 기능별 폴더 분리 |
| **FSD (Feature-Sliced Design)** | `fsd` | app/, pages/, widgets/, features/, entities/, shared/ 계층 구조 |
| **도메인 기반** | `domain-based` | 도메인명 폴더(users/, products/, orders/) 아래 각각 components, hooks 등 존재 |
| **자유 구조** | `custom` | 위 패턴에 해당하지 않거나 혼합 |

프리셋 매칭 시 `type` 값(영문)으로 비교한다.

---

### Step 3: 프리셋 매칭 (자동)

#### 3.1 프리셋 목록 로드
이 스킬 디렉토리의 `presets/` 폴더에서 모든 JSON 파일을 읽어 매칭을 시도한다.

#### 3.2 매칭 로직
1. package.json의 dependencies에서 각 프리셋의 `detection.required` 키를 대조한다
2. Step 2에서 분류한 아키텍처 패턴과 프리셋의 `architecture.type`을 대조한다
3. 두 조건이 모두 매칭되는 프리셋을 후보로 선택한다

#### 3.3 매칭 결과 분기

| 결과 | 다음 행동 |
|------|----------|
| 프리셋 1개 매칭 | 해당 프리셋을 초기 프로필로 사용 → Step 4에서 미세 조정 |
| 프리셋 여러 개 매칭 | 아래 동점 해소 규칙 적용 후, 여전히 동점이면 사용자에게 선택 요청 |
| 프리셋 0개 매칭 | 스캔 결과를 기반으로 빈 프로필 생성 → Step 4에서 문답으로 구성 |

**동점 해소 규칙** (프리셋 여러 개 매칭 시):
1. `detection.optional` 패키지 매칭 수가 더 많은 프리셋을 우선한다
2. 그래도 동점이면, `detection.required` 패키지 수가 더 많은(더 구체적인) 프리셋을 우선한다
3. 여전히 동점이면 사용자에게 후보 목록과 각 프리셋의 displayName을 제시하여 선택을 요청한다

---

### Step 4: 소크라테스 문답 (대화)

스캔과 딥스캔으로 파악한 내용 중 **확신이 부족한 부분**을 사용자에게 질문한다.
목표는 기계적 설문이 아니라, 에이전트가 "이 프로젝트를 이해하기 위한 대화"를 하는 것이다.

#### 4.1 문답 원칙

- **이미 코드에서 확인된 것은 묻지 않는다.** package.json에 `next`가 있으면 "Next.js를 쓰시나요?" 라고 묻지 않는다.
- **추론한 것은 확인을 구한다.** "폴더 구조를 보니 FSD 아키텍처를 사용하시는 것 같습니다. 맞나요?"
- **한 번에 3개 이내의 질문만 한다.** 긴 설문지를 던지지 않는다.
- **이전 답변에 따라 다음 질문이 달라진다.** 고정된 질문 목록이 아니다.
- **자연어로 대화한다.** JSON이나 특수 형식을 요구하지 않는다.

#### 4.1.1 질문 우선순위

질문 풀에서 질문을 선택할 때 다음 우선순위를 따른다:

| 우선순위 | 조건 | 질문 카테고리 |
|----------|------|-------------|
| 1 (필수) | 아키텍처 분류에 확신 부족 | 아키텍처 관련 |
| 2 (필수) | 프리셋 매칭 실패 또는 미세 조정 필요 | 의존성/레이어 규칙 |
| 3 (권장) | 코드만으로 파악 불가 | 프로젝트 의도 (한 줄 설명, 금지 사항) |
| 4 (선택) | 관련 라이브러리 감지 시 | 상태관리, 백엔드, 라우팅 |
| 5 (선택) | 코드 패턴 불일치 시 | 네이밍, 검증 환경 |

우선순위 1~2에 해당하는 질문이 있으면 반드시 첫 라운드에 포함한다.

#### 4.1.2 문답 종료 조건

다음 조건 중 하나를 만족하면 문답을 종료하고 Step 5(계획 제시)로 진행한다:

1. **프로필 필수 항목이 모두 채워짐** — 4.3의 [기본] 항목이 모두 확정된 상태
2. **최대 3라운드 소진** — 3회 문답 후에도 미확정 항목이 있으면, 스캔 기반 추론값을 기본값으로 사용하고 사용자에게 알린다
3. **사용자가 종료 요청** — "그냥 진행해줘", "기본값으로 해" 등

2번의 경우, 미확정 항목은 계획 제시 시 "추론값 사용" 표시와 함께 보여준다.

#### 4.2 질문 풀 (상황에 따라 선택)

아래는 질문 후보이다. 에이전트는 스캔 결과에 따라 필요한 것만 골라서 묻는다.

**아키텍처 관련** (Step 2에서 확신 부족 시):
- "소스 코드를 보니 {패턴}을 사용하시는 것 같습니다. 맞나요?"
- "폴더 간 의존성 방향이 있나요? 예를 들어 {A}에서 {B}를 import하는 건 허용되지만 반대는 안 되는 식인가요?"
- "{폴더X}와 {폴더Y}의 역할 차이가 무엇인가요?"
- "컴포넌트에서 API를 직접 호출하나요, 아니면 별도 레이어(훅, 서비스 등)를 거치나요?"

**프로젝트 의도 관련** (코드만으로 파악 불가):
- "이 프로젝트의 한 줄 설명을 해주시겠어요?"
- "현재 개발 단계가 어디인가요? (초기 셋업 / 기능 구현 중 / 리팩터링 중)"
- "특별히 지키고 싶은 코딩 규칙이나 컨벤션이 있나요?"
- "에이전트가 작업할 때 절대 하면 안 되는 것이 있나요?"

**검증 관련** (기존 테스트 환경이 불명확할 때):
- "테스트를 실행하는 명령은 무엇인가요?"
- "E2E 테스트를 사용하시나요?"
- "타입 체크 명령이 별도로 있나요?"

**네이밍/컨벤션 관련** (코드에서 일관된 패턴이 안 보일 때):
- "컴포넌트 파일명은 PascalCase, camelCase 중 어떤 걸 쓰시나요?"
- "테스트 파일은 소스 옆에 두나요, 별도 tests/ 폴더에 두나요?"

**상태 관리 관련** (Zustand, Redux 등이 감지된 경우):
- "스토어 파일은 어디에 두나요? (예: 슬라이스별 store.ts / shared/stores/ / 별도 폴더)"
- "스토어에 접근할 때 규칙이 있나요? (예: selector 함수만 사용, 직접 접근 금지 등)"
- "오프라인/로컬 영속성(persist 등)을 쓰고 있나요? 어디서 설정하나요?"

**백엔드/데이터 통합 관련** (Supabase, Firebase 등 BaaS가 감지된 경우):
- "DB 클라이언트(Supabase 등)는 어디서 초기화하나요? (예: shared/api/, shared/lib/)"
- "API 호출은 어디서 하나요? (예: entities/{이름}/api/, shared/api/, services/)"
- "인증(auth) 로직은 어디에 두나요?"
- "실시간 구독(real-time listener)을 사용하나요? 사용한다면 어디서 관리하나요?"

**도메인 모델 관련** (클래스 기반 객체, 복잡한 도메인 로직이 감지된 경우):
- "도메인 객체(모델)를 클래스로 관리하나요, 아니면 plain object + 함수 조합인가요?"
- "상태 전이 규칙이 있나요? (예: 특정 상태에서 특정 상태로만 변경 가능)"
- "도메인 객체를 변경할 때 직접 수정(mutation)하나요, 새 인스턴스를 반환하나요?"
- "이벤트 기록(히스토리, 감사 로그)을 남기나요? 어떤 구조인가요?"

**라우팅 관련** (React Router v7, Next.js App Router 등이 감지된 경우):
- "라우트 정의는 어디에 있나요? (예: app/routes/, routes.ts)"
- "loader/action 패턴을 사용하나요? 사용한다면 데이터 페칭은 loader에서 하나요, 컴포넌트에서 하나요?"

#### 4.3 프로필 완성

문답이 완료되면 수집된 모든 정보를 **프로젝트 프로필**로 통합한다.

프로필에 반드시 포함되어야 하는 항목:
```
[기본]
- 프로젝트명
- 한 줄 설명
- 스택 (프레임워크, 언어, 주요 라이브러리)
- 아키텍처 유형 (레이어 기반 / FSD / 도메인 기반 / 자유 구조)
- 폴더별 역할 (감지된 폴더 → 역할 매핑)
- 의존성 방향 규칙 (어떤 폴더가 어떤 폴더를 import 가능한지)
- 네이밍 규칙
- 개발 서버 명령 + 포트
- 테스트 명령 (유닛 / E2E)
- path alias 형태
- 소스 루트 경로

[해당 시 추가 — 문답에서 확인된 경우만]
- 상태 관리: 도구명, 스토어 위치, 접근 규칙
- 백엔드/DB 통합: 클라이언트 위치, API 호출 패턴, 인증 위치
- 도메인 모델: 객체 관리 방식(클래스/함수), 상태 전이 규칙, 변경 패턴(mutation/immutable)
- 데이터 영속성: 로컬 저장소 전략, 동기화 방식
- 라우팅 패턴: loader/action 사용 여부, 라우트 정의 위치
```

프리셋이 매칭된 경우: 프리셋 값을 기본으로 하되, 문답에서 다르게 확인된 부분을 오버라이드한다.
프리셋이 없는 경우: 스캔 + 문답 결과로 프로필을 직접 구성한다.

#### 4.4 기본값 테이블

사용자가 "몰라", "잘 모르겠어", "기본값으로" 등으로 답하면 아래 기본값을 적용한다.

| 프로필 항목 | 기본값 | 근거 |
|------------|--------|------|
| 프로젝트명 | package.json의 `name` 필드 | 패키지명이 곧 프로젝트명 |
| 한 줄 설명 | package.json의 `description`, 없으면 `"{name} 프로젝트"` | 기존 메타데이터 활용 |
| 아키텍처 유형 | 딥스캔 분류 결과, 분류 불가 시 `custom` (자유 구조) | 코드 기반 추론 우선 |
| 의존성 방향 규칙 | 매칭된 프리셋의 규칙, 프리셋 없으면 "규칙 없음" | 프리셋 참조 |
| 네이밍 규칙 | 컴포넌트 PascalCase, 훅 camelCase+use, 서비스 camelCase, 타입 PascalCase | React 커뮤니티 관행 |
| 개발 서버 명령 | package.json scripts의 `dev` 필드 | 실제 설정 기반 |
| 개발 서버 포트 | scripts.dev에서 추출, 불가 시 Next.js→3000, Vite→5173, 기타→3000 | 프레임워크 기본값 |
| 테스트 명령 | package.json scripts의 `test` 필드, 없으면 생략 | 실제 설정 기반 |
| E2E 프레임워크 | devDependencies에서 감지 (playwright/cypress), 없으면 생략 | 실제 설정 기반 |
| path alias | tsconfig.json `paths`에서 추출, 없으면 상대 경로 | 실제 설정 기반 |
| 소스 루트 | `src/` 존재 시 `src/`, 없으면 `app/` 존재 시 `app/`, 둘 다 없으면 사용자에게 질문 | 디렉토리 탐색 |

**기본값 사용 시 규칙**:
- 기본값을 적용한 항목은 Phase 4 보고에서 "(기본값)" 표시와 함께 나열한다
- 사용자가 나중에 수정할 수 있도록 해당 항목을 보고서에 명시한다

---

### Step 5: 계획 제시 & 승인

프로필이 완성되면 사용자에게 최종 계획을 제시한다.

```
## 🔍 프로젝트 분석 결과

### 프로젝트 프로필
- 프로젝트: {프로젝트명}
- 설명: {한 줄 설명}
- 스택: {프레임워크} + {언어} + {주요 라이브러리}
- 아키텍처: {유형} ({의존성 방향 한 줄 요약})
- 적용 프리셋: {프리셋명 또는 "커스텀 (프리셋 미사용)"}

### 감지된 폴더 구조
{소스루트}/
├── {폴더1}/  → {역할} ✅ 존재
├── {폴더2}/  → {역할} ✅ 존재
└── {폴더3}/  → {역할} (권장, 미존재)

### 의존성 규칙
{방향 도표 또는 테이블}

### 생성 예정 파일
1. CLAUDE.md (Agent Dispatch + 세션 요약)
2. AGENTS.md
3. ARCHITECTURE.md
4. .claude/rules/session-routine.md (TDD 오케스트레이션)
5. .claude/rules/coding-standards.md (코드 규칙)
6. agents/*.md (7개 TDD subagent 정의)
7. claude-progress.txt
8. feature_list.json
9. init.sh
10. docs/QUALITY_SCORE.md
11. docs/TECH_DEBT.md
12. docs/ 하위 디렉토리
13. scripts/structural-test.ts
14. scripts/doc-freshness.ts

### 수정 예정 파일
- package.json: scripts에 lint:arch, validate, doc:check 추가

### 스킵 항목
{이미 존재하는 파일}

---
이 내용으로 진행할까요? (y/n 또는 수정 요청)
```

**중요**: 사용자가 승인하기 전까지 어떤 파일도 생성하지 않는다.

---

## 5. Phase 2: 스캐폴딩

사용자가 승인하면 파일을 생성한다.

### 생성 순서

반드시 아래 순서대로 생성한다 (의존 관계 때문):

```
1. docs/ 디렉토리 구조 (빈 폴더):
   - `docs/product-specs/` — 제품 요구사항 문서
   - `docs/design-docs/` — 설계 결정 기록
   - `docs/exec-plans/` — 작업별 실행 계획
   - `docs/references/` — 참고 자료
2. ARCHITECTURE.md (아키텍처 규칙 — 다른 문서에서 참조)
3. AGENTS.md (전체 문서 맵 — ARCHITECTURE.md 경로 참조)
4. CLAUDE.md (Claude Code 전용 지침 — @AGENTS.md import + Agent Dispatch)
5. .claude/rules/session-routine.md (TDD 오케스트레이션 — CLAUDE.md가 참조)
6. .claude/rules/coding-standards.md (코드 규칙 — 프로필 기반)
7. .claude/rules/git-workflow.md (Git 규칙 — session-routine.md가 참조)
8. agents/*.md (7개 subagent 정의 — session-routine.md가 참조)
9. feature_list.json (빈 배열 또는 기존 코드 기반 추론)
10. claude-progress.txt (초기 상태 + TDD STATE 블록 포맷)
11. init.sh (스택에 맞는 초기화 스크립트)
12. scripts/structural-test.ts (아키텍처 규칙 검증)
13. scripts/doc-freshness.ts (문서 최신성 검사)
14. docs/QUALITY_SCORE.md (품질 점수표 초기값)
15. docs/TECH_DEBT.md (기술 부채 빈 템플릿)
16. package.json scripts 추가
```

### 5.1 AGENTS.md 생성 규칙

- 100줄 이내로 작성한다
- 백과사전이 아니라 **목차(Table of Contents)** 역할을 한다
- 프로필에서 확인된 실제 정보를 사용한다
- 플레이스홀더를 남기지 않는다
- AGENTS.md는 **프로젝트 구조와 현재 상태를 안내**하는 문서이다 (범용 에이전트용)
- 빌드/테스트 명령, 세션 루틴 등 **행동 지침은 CLAUDE.md에** 작성한다

포함해야 할 섹션:
```markdown
# AGENTS.md
## 프로젝트 개요        ← 프로젝트명, 스택, 한 줄 설명
## 아키텍처              ← ARCHITECTURE.md 링크 + 의존성 방향 한 줄 요약
## 현재 상태             ← claude-progress.txt, feature_list.json 링크
## 주요 규칙             ← 5개 이내의 핵심 규칙 (프로필에서 추출)
## 문서 맵               ← docs/ 하위 문서 테이블
```

### 5.1.1 CLAUDE.md 생성 규칙

CLAUDE.md는 **Claude Code가 세션 시작 시 자동으로 읽는 지침서**이다. AGENTS.md가 "이 프로젝트는 무엇인가"를 설명한다면, CLAUDE.md는 "이 프로젝트에서 어떻게 작업할 것인가"를 지시한다.

- 150줄 이내로 작성한다 (상세 규칙은 `.claude/rules/`로 분리)
- `@AGENTS.md`로 AGENTS.md를 import하여 프로젝트 개요를 중복 작성하지 않는다
- AGENTS.md에 이미 있는 정보(프로젝트 개요, 아키텍처 설명, 문서 맵)를 반복하지 않는다
- **행동 지침 중심**으로 작성한다: 명령어, 에이전트 디스패치, 금지 사항
- 코드 규칙과 세션 루틴 상세는 `.claude/rules/`에 위임한다

포함해야 할 섹션:
```markdown
# CLAUDE.md

@AGENTS.md

## 명령어
- 개발 서버: {프로필의 devServer.command} (포트: {port})
- 테스트: {프로필의 테스트 명령}
- 타입 체크: {프로필의 typecheck 명령, 있을 경우}
- 전체 검증: npm run validate
- 아키텍처 검증: npm run lint:arch

## TDD Subagent 파이프라인

기능 구현은 TDD 사이클(Red → Green → Refactor)을 따른다.
각 단계의 전문 에이전트를 Agent tool로 호출한다.
상세 오케스트레이션: .claude/rules/session-routine.md

| TDD 단계 | Agent | 파일 |
|----------|-------|------|
| Pre-Red | Architect | agents/architect.md |
| Red | Test Engineer | agents/test-engineer.md |
| Green | Implementer | agents/implementer.md |
| Post-Green | Reviewer | agents/reviewer.md |
| Refactor | Simplifier | agents/simplifier.md |
| On-demand | Debugger | agents/debugger.md |
| Post-Green | Security Reviewer | agents/security-reviewer.md |

### 호출 방법
1. agents/{name}.md를 읽어 에이전트 정의를 확인한다
2. Input 섹션에 명시된 데이터를 수집한다
3. Agent tool로 subagent를 호출한다

## 세션 루틴 (요약)
### 시작
1. claude-progress.txt 읽기 (TDD STATE 블록 확인)
2. git status → 미커밋 변경 확인
3. git log --oneline -10
4. feature_list.json → passes: false 중 최고 우선순위 선택
5. npm run validate (회귀 체크)
6. TDD 사이클 시작 (상세: .claude/rules/session-routine.md)

### 종료
1. npm run validate
2. feature_list.json 업데이트
3. claude-progress.txt 세션 요약 + TDD STATE 갱신
4. git-workflow.md 규칙에 따라 커밋 제안

## 금지 사항
- feature_list.json의 기능 설명을 수정/삭제하지 않는다
- 한 번에 여러 기능을 구현하지 않는다
- 테스트 없이 기능을 완료 처리하지 않는다
{프로필의 "에이전트가 하면 안 되는 것"에서 추출}
```

**AGENTS.md와 CLAUDE.md의 역할 분리:**

원칙: **AGENTS.md = "이 프로젝트는 무엇인가" (맥락)**, **CLAUDE.md = "어떻게 작업할 것인가" (행동)**. 동일한 정보를 두 파일에 모두 적지 않는다. 충돌 시 CLAUDE.md가 행동 지침의 source of truth이다. 코드 규칙과 세션 루틴 상세는 `.claude/rules/`에 위임한다.

| 내용 | CLAUDE.md | .claude/rules/ | AGENTS.md |
|------|-----------|----------------|-----------|
| 프로젝트 개요, 스택 | ❌ (@AGENTS.md import) | ❌ | ✅ (source of truth) |
| 아키텍처 설명, 문서 맵 | ❌ | ❌ | ✅ + ARCHITECTURE.md |
| 빌드/테스트/검증 명령 | ✅ (source of truth) | ❌ | ❌ |
| Agent Dispatch 테이블 | ✅ (요약) | session-routine.md (상세) | ❌ |
| 코드 스타일/네이밍 규칙 | ❌ | coding-standards.md (source of truth) | ❌ |
| TDD 오케스트레이션 상세 | ❌ | session-routine.md (source of truth) | ❌ |
| 세션 시작/종료 루틴 | ✅ (요약) | session-routine.md (상세) | ❌ |
| Git 워크플로 (커밋, 브랜치, 충돌) | ❌ | git-workflow.md (source of truth) | ❌ |
| 금지 사항 | ✅ | coding-standards.md에도 포함 | ❌ |
| 현재 상태 링크 | ❌ | ❌ | ✅ (source of truth) |

### 5.2 ARCHITECTURE.md 생성 규칙

- **프로필의 아키텍처 정보를 기반으로** 작성한다 (하드코딩하지 않음)
- 포함해야 할 내용:
  - 아키텍처 유형과 설명
  - 폴더별 역할 테이블 (프로필의 폴더-역할 매핑 사용)
  - 의존성 방향 규칙 (프로필의 의존성 규칙 사용)
  - 네이밍 규칙 (프로필의 네이밍 규칙 사용)
  - 실제 존재하는 폴더는 ✅, 존재하지 않는 폴더는 "권장"으로 표시
  - 의존성 규칙에서 참조되는 레이어가 실제로 존재하지 않는 경우, 해당 레이어에 ⚠️ 표시와 함께 "의존 규칙에 포함되나 폴더 미존재 — 생성 권장" 메시지를 추가한다
- 프로필에 추가 항목이 있으면 해당 섹션도 포함한다:
  - 상태 관리 → "상태 관리" 섹션: 스토어 위치, 접근 규칙
  - 백엔드/DB 통합 → "데이터 계층" 섹션: 클라이언트 위치, API 호출 패턴
  - 도메인 모델 → "도메인 규칙" 섹션: 객체 관리 방식, 상태 전이, 변경 패턴
  - 라우팅 패턴 → "라우팅" 섹션: loader/action 규칙, 라우트 구조
- 추가 항목이 없으면 해당 섹션은 생략한다 (빈 섹션을 만들지 않음)
- 폴더를 직접 생성하지 않는다 (문서에 기록만 한다)

아키텍처 유형별 ARCHITECTURE.md의 핵심 구조:

**레이어 기반**:
```
의존성 방향: {레이어1} → {레이어2} → ... → {레이어N}
각 레이어는 왼쪽(하위) 레이어만 import 가능
```

**FSD**:
```
의존성 방향: app → pages → widgets → features → entities → shared
각 레이어는 아래쪽 레이어만 import 가능
같은 레이어 내 슬라이스 간 cross-import 금지
```

**도메인 기반**:
```
공유 모듈(shared/)은 모든 도메인에서 import 가능
도메인 간 직접 import는 금지 (이벤트 또는 공유 인터페이스를 통해 통신)
```

**자유 구조**:
```
명시적 레이어 규칙 없음 — 문답에서 확인된 규칙만 기록
```

### 5.3 feature_list.json 생성 규칙

- 새 프로젝트 (소스 코드 없음): 빈 배열 `[]`로 생성
- 기존 프로젝트 (소스 코드 있음): 소스 코드를 분석하여 현재 구현된 기능을 추론하고 항목을 생성
- passes 필드 설정 기준:
  - `passes: true` — 에이전트가 기능 동작을 **직접 확인**한 경우. 다음 중 하나 이상을 만족해야 한다:
    - 해당 기능의 테스트가 존재하고, 테스트 실행 결과 통과
    - 개발 서버에서 해당 기능을 직접 동작시켜 확인 (E2E, 수동 확인)
    - 기능에 해당하는 steps를 모두 수행하여 통과 확인
  - `passes: false` — 코드는 존재하지만 위 조건을 충족하지 못한 경우. 이 때 `notes: "코드 존재 — 검증 필요"` 기록
  - 하네스 셋업 시점에는 직접 확인이 불가하므로, **기존 코드 기반 추론 항목은 모두 `passes: false`로 설정**한다
  - 이후 에이전트가 세션 종료 루틴에서 검증한 기능만 `passes: true`로 전환한다
- 형식:
```json
[
  {
    "id": "F001",
    "category": "카테고리",
    "priority": 1,
    "description": "기능 설명",
    "steps": ["검증 단계 1", "검증 단계 2"],
    "passes": false,
    "last_session": null,
    "notes": "코드 존재 — 검증 필요"
  }
]
```

### 5.4 structural-test.ts 생성 규칙

- 이 스킬의 `templates/` 디렉토리에서 아키텍처 유형에 맞는 템플릿을 기반으로 생성한다
- 템플릿의 치환 대상:
  - `LAYER_RULES` — 프로필의 `architecture.layers.rules` 값으로 치환
  - `PATH_ALIAS` — 프로필의 `pathAlias` 값으로 치환. 배열인 경우 각 alias에 대해 regex를 생성하여 모두 검사한다 (예: `['@/', '~/']` → `@/` 또는 `~/`로 시작하는 import 모두 감지)
  - `SRC_ROOT` — 프로필의 `srcRoot` 값으로 치환

| 아키텍처 유형 | 사용 템플릿 | 검증 항목 |
|--------------|-----------|----------|
| 레이어 기반 (`layer-based`) | `templates/structural-test-layer.ts` | 레이어 의존성 방향 (alias + 상대경로) |
| FSD (`fsd`) | `templates/structural-test-fsd.ts` | 레이어 의존성 + cross-slice import + public API |
| 도메인 기반 (`domain-based`) | 동적 생성 | 도메인 간 직접 import 감지 |
| 자유 구조 (`custom`) | 동적 생성 | 프로필에 명시된 금지 규칙만 (없으면 빈 검사) |

- 템플릿이 없는 유형(domain-based, custom)은 프로필의 규칙을 기반으로 동적으로 생성한다
- import 패턴 감지 시 다음 두 가지를 모두 검사한다:
  - alias import: `from '@/{layer}/...'` 등 pathAlias 기반
  - 상대 경로 import: `from '../../{layer}/...'` — srcRoot 기준으로 레이어 폴더를 추론
- 실행 가능한 스크립트로 만든다: `npx tsx scripts/structural-test.ts`
- 위반 발견 시 파일, 줄 번호, 위반 내용을 출력하고 exit 1로 종료

### 5.5 package.json scripts 추가 규칙

- 기존 scripts를 **절대 삭제하지 않는다**
- 다음 항목만 추가한다:
  - `lint:arch`: 프리셋 또는 프로필의 `scripts.lint:arch` 값 사용
  - `validate`: **항상 동적으로 조합한다** (프리셋에서 가져오지 않음 — 아래 조합 규칙 참조)
  - `doc:check`: 문서 최신성 검사
- 기존에 같은 이름의 script가 있으면 스킵한다
- Node 스크립트로 안전하게 수정한다:

```bash
node -e "
const pkg = require('./package.json');
const toAdd = {
  'lint:arch': '{프로필에서 가져온 lint:arch 명령}',
  'validate': '{프로필에서 가져온 validate 명령}',
  'doc:check': '{프로필에서 가져온 doc:check 명령}'
};
let changed = false;
for (const [key, val] of Object.entries(toAdd)) {
  if (!pkg.scripts[key]) {
    pkg.scripts[key] = val;
    changed = true;
  }
}
if (changed) {
  require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
  console.log('✅ package.json scripts 추가 완료');
} else {
  console.log('ℹ️ 추가할 scripts 없음 (이미 존재)');
}
"
```

validate 명령 조합 규칙:
- typecheck 명령이 package.json scripts에 있으면 포함, 없으면 생략
- lint 명령이 있으면 포함, 없으면 생략
- lint:arch는 항상 포함
- test 명령이 있으면 포함, 없으면 생략
- 예시: `npm run typecheck && npm run lint && npm run lint:arch && npm run test`
- 예시 (typecheck 없는 경우): `npm run lint && npm run lint:arch && npm run test`

### 5.6 init.sh 생성 규칙

- 프로필의 개발 서버 정보를 사용한다
- 실행 권한을 부여한다: `chmod +x init.sh`
- 스크립트 구조:

```bash
#!/bin/bash
set -e

echo "=== 환경 초기화 ==="

# 1. 패키지 매니저 감지 (lockfile 기반)
#    - pnpm-lock.yaml → pnpm install
#    - yarn.lock → yarn install
#    - package-lock.json 또는 기타 → npm install

# 2. 의존성 설치 (node_modules 없을 때만)
if [ ! -d "node_modules" ]; then
  echo "의존성 설치 중..."
  {감지된 패키지 매니저} install
fi

# 3. 개발 서버 실행 (백그라운드)
echo "개발 서버 시작..."
{프로필의 devServer.command} &
DEV_PID=$!

# 4. 서버 준비 대기
echo "서버 준비 대기 중..."
for i in $(seq 1 30); do
  if {프로필의 devServer.readyCheck} 2>/dev/null | grep -q "200"; then
    echo "✅ 서버 정상 동작 (http://localhost:{프로필의 devServer.port})"
    break
  fi
  sleep 1
done

echo "=== 초기화 완료 (PID: $DEV_PID) ==="
```

- `{...}` 부분은 프로필의 실제 값으로 치환한다
- readyCheck가 프로필에 없으면 기본 커맨드를 사용한다: `curl -s -o /dev/null -w '%{http_code}' http://localhost:{port}`
- readyCheck 파싱 규칙:
  - readyCheck 명령의 **stdout 출력에 "200"이 포함되면** 준비 완료로 판정한다
  - 프리셋의 readyCheck는 반드시 stdout에 HTTP 상태 코드를 출력하는 형태여야 한다 (예: `curl -w '%{http_code}'`)
  - readyCheck 명령이 exit 0이지만 "200"이 없으면 준비 미완료로 간주한다
  - 30초(30회 반복) 내 "200"이 나오지 않으면 경고를 출력하고 계속 진행한다 (중단하지 않음)

### 5.7 doc-freshness.ts 생성 규칙

- 문서 최신성을 검사하는 스크립트를 생성한다: `npx tsx scripts/doc-freshness.ts`
- 검사 대상 문서:
  - AGENTS.md
  - ARCHITECTURE.md
  - docs/ 하위의 모든 .md 파일
- 검사 로직:
  - 각 파일의 최종 수정일(`fs.statSync(file).mtimeMs`)을 현재 시간과 비교한다
  - staleness 기준: 프로필의 `docFreshnessDays` 값 (기본값: **14일**)
  - 기준일 이내 수정 → ✅ 최신 / 기준일 초과 → ⚠️ 오래됨
  - 프리셋에 `docFreshnessDays` 필드가 있으면 해당 값을 사용하고, 없으면 14일을 기본값으로 사용한다
- 출력 형식:
  ```
  📄 문서 최신성 검사
  ✅ AGENTS.md — 3일 전 수정
  ✅ ARCHITECTURE.md — 1일 전 수정
  ⚠️ docs/QUALITY_SCORE.md — 21일 전 수정
  ⚠️ docs/TECH_DEBT.md — 45일 전 수정

  결과: 4개 문서 중 2개 오래됨
  ```
- exit 동작: **항상 exit 0** — 경고만 출력하고 validate를 차단하지 않는다
- 파일이 존재하지 않으면 해당 항목은 "❌ {파일명} — 파일 없음"으로 출력한다

### 5.8 docs/QUALITY_SCORE.md 생성 규칙

- 프로젝트 품질을 측정하는 점수표의 초기 템플릿을 생성한다
- 구조:

```markdown
# 품질 점수표

> 현재 점수: 미측정 / 100
> 마지막 측정일: —

## 카테고리별 점수

| 카테고리 | 배점 | 점수 | 기준 |
|----------|------|------|------|
| 타입 안전성 | 20 | — | any/unknown 사용 최소화, strict 모드 |
| 테스트 커버리지 | 20 | — | 핵심 경로 유닛/통합 테스트 존재 |
| 아키텍처 준수 | 20 | — | structural-test 위반 0건 |
| 접근성 | 15 | — | 시맨틱 HTML, ARIA, 키보드 네비게이션 |
| 성능 | 15 | — | 번들 크기, LCP, 불필요한 리렌더링 |
| 문서 최신성 | 10 | — | doc-freshness 경고 0건 |

## 알려진 이슈
<!-- 에이전트가 발견한 품질 이슈를 여기에 기록한다 -->
```

- 각 카테고리의 점수는 초기에 모두 "—"로 설정한다
- 에이전트 또는 사용자가 측정 후 점수를 업데이트한다

### 5.9 docs/TECH_DEBT.md 생성 규칙

- 기술 부채를 추적하는 빈 템플릿을 생성한다
- 구조:

```markdown
# 기술 부채 관리

> 마지막 업데이트: {생성일}

## 긴급 (Critical)
<!-- 즉시 수정 필요 — 기능 장애, 보안 취약점, 데이터 손실 위험 -->

## 높음 (High)
<!-- 다음 스프린트 내 수정 권장 — 성능 저하, 아키텍처 위반, 테스트 누락 -->

## 보통 (Medium)
<!-- 여유 있을 때 수정 — 코드 중복, 네이밍 불일치, 타입 불완전 -->

## 낮음 (Low)
<!-- 장기 개선 과제 — 리팩터링 기회, 의존성 업그레이드, DX 개선 -->

## 리팩터링 대상

| 파일/모듈 | 문제 | 심각도 | 비고 |
|-----------|------|--------|------|
<!-- 에이전트가 발견한 리팩터링 대상을 여기에 기록한다 -->
```

- 모든 섹션은 초기에 비어 있다 (주석만 포함)
- 에이전트가 작업 중 발견한 부채를 여기에 기록한다

### 5.10 agents/ 생성 규칙

프로젝트에 TDD subagent 파이프라인을 위한 에이전트 정의 파일을 생성한다.

#### 5.10.1 생성할 파일

| 파일 | 역할 | TDD 단계 | 접근 권한 |
|------|------|----------|----------|
| `agents/architect.md` | 기능 분석 + 구현 계획 수립 | Pre-Red | Read-only |
| `agents/test-engineer.md` | 실패하는 테스트 작성 | Red | Write (테스트만) |
| `agents/implementer.md` | 최소 구현으로 테스트 통과 | Green | Write (소스만) |
| `agents/reviewer.md` | 코드 리뷰 + 품질 게이트 | Post-Green | Read-only |
| `agents/simplifier.md` | 리팩터링 (테스트 유지) | Refactor | Write (소스만) |
| `agents/debugger.md` | 근본 원인 진단 + 수정 | On-demand | Write |
| `agents/security-reviewer.md` | 보안 취약점 점검 | Post-Green | Read-only |

#### 5.10.2 생성 방식

이 스킬의 `templates/agents/` 디렉토리에서 템플릿을 읽어 프로젝트의 `agents/` 디렉토리에 복사하며, 플레이스홀더를 프로필 값으로 치환한다.

#### 5.10.3 플레이스홀더 치환 규칙

| 플레이스홀더 | 소스 | 기본값 | 사용하는 에이전트 |
|-------------|------|--------|-----------------|
| `{{VALIDATE_COMMAND}}` | 프로필 scripts.validate | `npm run validate` | implementer, simplifier, debugger |
| `{{TEST_COMMAND}}` | 프로필 scripts.test | `npm run test` | test-engineer |
| `{{SECURITY_CATEGORIES}}` | 프리셋 tdd.securityCategories | `auth, security, api, payment` | security-reviewer |
| `{{MAX_IMPLEMENTER_ATTEMPTS}}` | 프리셋 tdd.maxImplementerAttempts | `3` | session-routine (참조) |
| `{{MAX_DEBUGGER_ATTEMPTS}}` | 프리셋 tdd.maxDebuggerAttempts | `2` | session-routine (참조) |

치환 후 `{{...}}` 패턴이 남아 있으면 검증 단계에서 에러로 보고한다.

#### 5.10.4 에이전트 정의 파일 구조

모든 에이전트 파일은 다음 섹션을 포함한다:

```markdown
# {에이전트 이름}

## Role          ← 한 줄 역할 설명
## Access        ← Read-only | Read-write (범위 명시)
## Input         ← Orchestrator가 전달하는 데이터
## Instructions  ← 상세 행동 지침
## Output Format ← 구조화된 출력 형식 (Orchestrator가 파싱)
## Constraints   ← 절대 하지 않는 것
## Circuit Breaker ← 에스컬레이션 조건과 행동
```

#### 5.10.5 Subagent 호출 방법

CLAUDE.md 또는 `.claude/rules/session-routine.md`에서 에이전트를 호출할 때:

1. `agents/{name}.md` 파일을 읽는다
2. 에이전트의 Input 섹션에 명시된 데이터를 수집한다
3. **Claude Code의 Agent tool**로 subagent를 spawning한다:
   - prompt: 에이전트 정의 전체 + 입력 데이터
   - description: "{에이전트명}: {feature ID}"
4. subagent의 Output Format에 맞는 결과를 받아 다음 단계 결정에 사용한다

### 5.11 .claude/rules/ 생성 규칙

CLAUDE.md의 코드 규칙과 세션 루틴 상세를 `.claude/rules/` 파일로 분리하여 생성한다.

#### 5.11.1 생성할 파일

| 파일 | 역할 | paths 설정 |
|------|------|-----------|
| `.claude/rules/session-routine.md` | TDD 오케스트레이션 플로우, 상태 머신, 에스컬레이션 규칙 | 없음 (항상 로딩) |
| `.claude/rules/coding-standards.md` | 아키텍처 규칙, 네이밍 규칙, 코드 원칙 | 없음 (항상 로딩) |
| `.claude/rules/git-workflow.md` | Git 커밋 규칙, 브랜치 정책, 충돌 해결, 세션 경계 | 없음 (항상 로딩) |

프로필의 추가 항목에 따라 도메인별 rule 파일을 추가로 생성할 수 있다:

| 프로필 추가 항목 | 생성 파일 | paths 설정 |
|-----------------|----------|-----------|
| 상태 관리 (Zustand 등) | `.claude/rules/state-management.md` | 스토어 위치 경로 |
| 백엔드/DB 통합 (Supabase 등) | `.claude/rules/api-patterns.md` | API 클라이언트 위치 경로 |
| 도메인 모델 | `.claude/rules/domain-model.md` | 도메인 폴더 경로 |

도메인별 rule 파일은 해당 프로필 항목이 문답에서 확인된 경우에만 생성한다.

#### 5.11.2 생성 방식

이 스킬의 `templates/rules/` 디렉토리에서 템플릿을 읽어 프로젝트의 `.claude/rules/` 디렉토리에 복사하며, 플레이스홀더를 프로필 값으로 치환한다.

#### 5.11.3 플레이스홀더 치환 규칙

session-routine.md:

| 플레이스홀더 | 소스 | 기본값 |
|-------------|------|--------|
| `{{VALIDATE_COMMAND}}` | 프로필 scripts.validate | `npm run validate` |
| `{{TEST_COMMAND}}` | 프로필 scripts.test | `npm run test` |
| `{{SECURITY_CATEGORIES}}` | 프리셋 tdd.securityCategories | `auth, security, api, payment` |
| `{{MAX_IMPLEMENTER_ATTEMPTS}}` | 프리셋 tdd.maxImplementerAttempts | `3` |
| `{{MAX_DEBUGGER_ATTEMPTS}}` | 프리셋 tdd.maxDebuggerAttempts | `2` |

coding-standards.md:

| 플레이스홀더 | 소스 | 기본값 |
|-------------|------|--------|
| `{{ARCHITECTURE_TYPE}}` | 프로필 architecture.type | `custom` |
| `{{LAYER_RULES_SUMMARY}}` | 프로필 architecture.layers.order 배열을 `→`로 연결 | 없음 |
| `{{NAMING_RULES}}` | 프로필 naming 항목을 줄 단위로 조합 | React 커뮤니티 관행 |
| `{{PATH_ALIAS}}` | 프로필 pathAlias | `@/` |

git-workflow.md:

| 플레이스홀더 | 소스 | 기본값 |
|-------------|------|--------|
| `{{COMMIT_SCOPES}}` | 프로필 architecture.layers.order → scope 변환 + `docs`, `config`, `test` 추가. 프리셋에 git.commitScopes가 명시되어 있으면 그것을 사용 | `core, ui, api, config, test, docs` |
| `{{COMMIT_LANG_LABEL}}` | 프리셋 git.commitLang → 라벨 매핑 (`ko` → `한국어`, `en` → `English`) | `한국어` |
| `{{BRANCH_PREFIX_POLICY_FORMATTED}}` | 프리셋 git.branchPrefixes 배열을 줄바꿈 + 주석 형식으로 렌더 | `feature/  # 새 기능`\n`fix/  # 버그 수정`\n`docs/  # 문서 변경`\n`refactor/  # 구조 개선`\n`chore/  # 설정/도구` |
| `{{MAIN_BRANCH}}` | 프리셋 git.mainBranch 또는 `git branch` 감지 | `main` |
| `{{VALIDATE_COMMAND}}` | 프로필 scripts.validate | `npm run validate` |

#### 5.11.4 CLAUDE.md와의 역할 분리

`.claude/rules/` 파일이 생성되면 CLAUDE.md에서 해당 내용을 제거한다:

| 내용 | CLAUDE.md | .claude/rules/ | 비고 |
|------|-----------|----------------|------|
| TDD 플로우 상세 | ❌ | session-routine.md | Agent Dispatch 테이블만 CLAUDE.md에 유지 |
| 에스컬레이션 규칙 | ❌ | session-routine.md | |
| 코드 규칙 (네이밍 등) | ❌ | coding-standards.md | |
| 아키텍처 유형별 핵심 규칙 | ❌ | coding-standards.md | |
| 명령어 | ✅ | ❌ | |
| @AGENTS.md import | ✅ | ❌ | |
| Agent Dispatch 테이블 | ✅ | ❌ | 간략 버전 (어떤 에이전트가 있는지) |
| 금지 사항 | ✅ | coding-standards.md에도 포함 | 중요한 것은 양쪽 모두 |

---

## 6. Phase 3: 검증

생성이 완료되면 자동으로 검증한다.

### 검증 체크리스트

```bash
# 6.0 필요한 디렉토리 생성 보장
mkdir -p scripts/ docs/ agents/ .claude/rules/

# 6.1 생성된 파일 존재 확인
ls -la CLAUDE.md AGENTS.md ARCHITECTURE.md claude-progress.txt feature_list.json init.sh

# 6.2 docs/ 구조 확인
ls -la docs/

# 6.3 scripts/ 확인
ls -la scripts/structural-test.ts scripts/doc-freshness.ts

# 6.4 agents/ 확인
ls -la agents/architect.md agents/test-engineer.md agents/implementer.md agents/reviewer.md agents/simplifier.md agents/debugger.md agents/security-reviewer.md

# 6.5 .claude/rules/ 확인
ls -la .claude/rules/session-routine.md .claude/rules/coding-standards.md .claude/rules/git-workflow.md

# 6.6 AGENTS.md 내부 참조 경로 검증
# AGENTS.md에 명시된 모든 파일 경로가 실제로 존재하는지 확인

# 6.7 ARCHITECTURE.md의 폴더 목록이 실제 디렉토리와 일치하는지 확인

# 6.8 package.json scripts 확인
node -e "const pkg=require('./package.json'); console.log(pkg.scripts['lint:arch'] ? '✅ lint:arch' : '❌ lint:arch 누락'); console.log(pkg.scripts['validate'] ? '✅ validate' : '❌ validate 누락');"

# 6.9 structural-test.ts 실행 가능 여부 (dry run)
npx tsx scripts/structural-test.ts 2>&1 || echo "⚠️ structural-test 실행 실패 — 수동 확인 필요"

# 6.10 feature_list.json이 valid JSON인지 확인
node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8')); console.log('✅ feature_list.json valid');" 2>&1 || echo "❌ feature_list.json invalid"

# 6.11 에이전트 파일에 미치환 플레이스홀더가 없는지 확인
grep -r '{{.*}}' agents/ .claude/rules/ 2>/dev/null && echo "❌ 미치환 플레이스홀더 발견" || echo "✅ 플레이스홀더 모두 치환됨"
```

### 검증 결과 판정
- 모든 항목 통과 → Phase 4로 진행
- 일부 실패 → 아래 자동 수정 전략에 따라 1회 시도, 그래도 실패 시 사용자에게 보고
- 치명적 실패 (파일 생성 자체가 안 됨) → 즉시 사용자에게 보고

### 자동 수정 가능 항목

| 검증 항목 | 자동 수정 방법 |
|-----------|--------------|
| 파일 누락 (6.1/6.2/6.3/6.4/6.5) | 해당 파일을 다시 생성 |
| AGENTS.md 경로 불일치 (6.6) | AGENTS.md에서 잘못된 경로를 실제 경로로 수정 |
| package.json scripts 누락 (6.8) | 누락된 script를 다시 추가 |
| feature_list.json invalid JSON (6.10) | 파일을 빈 배열 `[]`로 재생성 |
| 미치환 플레이스홀더 (6.11) | 해당 파일의 플레이스홀더를 프로필 기본값으로 재치환 |

### 자동 수정 불가 항목 (사용자 보고)

| 검증 항목 | 사용자에게 보고할 내용 |
|-----------|---------------------|
| ARCHITECTURE.md 폴더 불일치 (6.5) | 어떤 폴더가 불일치하는지 목록 제시 |
| structural-test.ts 실행 실패 (6.7) | 에러 메시지와 함께 수동 수정 제안 |

---

## 7. Phase 4: 보고

최종 결과를 사용자에게 보고한다.

### 보고 포맷

```
## ✅ 하네스 셋업 완료

### 프로젝트 프로필
- 프로젝트: {프로젝트명}
- 아키텍처: {유형}
- 적용 프리셋: {프리셋명 또는 커스텀}

### 생성된 파일
| 파일 | 상태 | 설명 |
|------|------|------|
| CLAUDE.md | ✅ | Claude Code 지침서 ({N}줄) |
| AGENTS.md | ✅ | 에이전트 입구 문서 ({N}줄) |
| ARCHITECTURE.md | ✅ | {아키텍처 유형} 규칙 문서 |
| agents/*.md | ✅ | TDD subagent 정의 (7개) |
| .claude/rules/session-routine.md | ✅ | TDD 오케스트레이션 플로우 |
| .claude/rules/coding-standards.md | ✅ | 코드 규칙 |
| .claude/rules/git-workflow.md | ✅ | Git 워크플로 규칙 |
| feature_list.json | ✅ | 기능 {N}개 |
| claude-progress.txt | ✅ | 초기 기록 (TDD STATE 포맷 포함) |
| init.sh | ✅ | 환경 초기화 스크립트 |
| docs/ | ✅ | 하위 디렉토리 |
| scripts/structural-test.ts | ✅ | 아키텍처 규칙 검증 |
| scripts/doc-freshness.ts | ✅ | 문서 최신성 검사 |
| package.json | ✅ 수정 | lint:arch, validate 추가 |

### 검증 결과
- ✅ 파일 경로 일관성: 통과
- ✅ JSON 유효성: 통과
- ✅ structural-test: 통과 (위반 {N}건)
- ✅ package.json scripts: 정상
- ✅ agents/ 파일 (7개): 정상
- ✅ .claude/rules/ 파일 (3개): 정상
- ✅ 플레이스홀더 치환: 완료

### 다음 단계
1. `npm run validate`를 실행하여 전체 검증이 동작하는지 확인하세요
2. AGENTS.md를 읽고 프로젝트 설명이 정확한지 확인하세요
3. feature_list.json에 구현할 기능을 추가하세요
4. 첫 번째 기능을 선택하고 TDD 사이클을 시작하세요

### TDD 워크플로 안내
기능 구현은 TDD subagent 파이프라인을 따릅니다:

**사이클**: Architect → Test Engineer (Red) → Implementer (Green) → Reviewer → Simplifier (Refactor)
**상세 플로우**: `.claude/rules/session-routine.md` 참조
**에이전트 정의**: `agents/` 디렉토리

**세션 시작**: claude-progress.txt → git status → git log → feature_list.json → validate (회귀 체크) → TDD 사이클
**세션 종료**: validate → feature_list.json 업데이트 → progress 기록 → git-workflow.md 규칙에 따라 커밋 제안
```

---

## 8. 프리셋 시스템

### 프리셋 파일 위치
이 스킬 디렉토리의 `presets/` 폴더에 위치한다.
```
presets/
├── react-next.json
├── react-router-fsd.json
└── (추가 프리셋)
```

### 프리셋 스키마

```json
{
  "name": "프리셋 식별자",
  "displayName": "사람이 읽을 수 있는 이름",
  "description": "프리셋 설명",

  "detection": {
    "required": ["매칭에 필요한 패키지명"],
    "optional": ["있으면 좋은 패키지명"],
    "versionConstraints": {
      "패키지명": ">=13.0.0"
    }
  },

  "architecture": {
    "type": "layer-based | fsd | domain-based | custom",
    "description": "아키텍처 한 줄 설명",
    "layers": {
      "order": ["의존 방향 순서대로 나열"],
      "rules": {
        "레이어명": { "allowedImports": ["import 가능한 레이어"] }
      },
      "descriptions": {
        "레이어명": "역할 설명"
      }
    },
    "extraRules": [
      "레이어 규칙 외 추가 제약 (자연어)"
    ]
  },

  "naming": {
    "폴더 또는 파일 유형": "네이밍 규칙 설명"
  },

  "scripts": {
    "lint:arch": "아키텍처 검증 명령",
    "doc:check": "문서 검사 명령"
  },

  "devServer": {
    "command": "개발 서버 실행 명령",
    "port": 3000,
    "readyCheck": "서버 준비 확인 명령"
  },

  "pathAlias": "@/",
  "srcRoot": "src/",

  "testFramework": {
    "unit": "유닛 테스트 도구",
    "e2e": "E2E 테스트 도구"
  },

  "docFreshnessDays": 14,

  "git": {
    "mainBranch": "main",
    "branchPrefixes": ["feature/", "fix/", "docs/", "refactor/", "chore/"],
    "commitLang": "ko"
  }
}
```

**타입 참고**: `pathAlias`는 `string` 또는 `string[]` 가능. 단일 alias(`"@/"`)이면 문자열, 복수 alias(`["@/", "~/"]`)이면 배열로 지정한다.

**git 참고**: `git` 필드는 모든 하위 필드에 기본값이 있으므로 프리셋에서 생략 가능하다. `commitLang`은 `"ko"` (한국어) 또는 `"en"` (English)을 지원한다.

### 프리셋 매칭 로직
1. 이 스킬의 `presets/` 디렉토리 내 모든 JSON 파일을 로드한다
2. package.json의 dependencies/devDependencies에서 각 프리셋의 `detection.required` 패키지를 모두 대조한다
3. 모든 required가 매칭되는 프리셋을 1차 후보로 선택한다
3.5. `detection.versionConstraints`가 있으면 해당 패키지의 실제 버전(package.json에 명시된)이 조건을 만족하는지 확인한다. 조건 미충족 시 해당 프리셋을 후보에서 제외한다. (semver 범위 문법 사용: `>=`, `<`, `^`, `~` 등)
4. 남은 후보 중 `architecture.type`이 Step 2 딥스캔 결과와 일치하는 것을 최종 후보로 선택한다
5. 최종 후보가 여러 개면: 각 후보의 `detection.optional` 패키지 매칭 개수를 세어 가장 많이 매칭되는 것을 우선 선택한다
6. 최종 후보가 0개면: 프리셋 없이 진행 (문답으로 프로필 구성)
7. 최종 후보가 1개면: 해당 프리셋 사용
8. 5단계 이후에도 여러 개면: 사용자에게 선택 요청

---

## 9. 절대 규칙

### 파일 보호
- 기존 소스 코드 (.ts, .tsx, .js, .jsx, .css 등)를 수정하지 않는다
- 기존 설정 파일을 덮어쓰지 않는다 (merge만 허용, 그것도 scripts 필드에 한정)
- 이미 존재하는 하네스 파일을 덮어쓰지 않는다 (사용자 확인 없이)
- node_modules, .git, 프레임워크 캐시 디렉토리(.next, dist 등)에 접근하지 않는다

### 문서 품질
- AGENTS.md는 100줄을 넘기지 않는다
- 모든 문서의 경로 참조는 실제 파일/폴더와 일치해야 한다
- 플레이스홀더 텍스트(TODO, TBD, Lorem 등)를 남기지 않는다
- 한국어로 작성한다 (사용자 요청이 없는 한)

### 실행 안전
- 사용자 승인 없이 파일을 생성하지 않는다
- git commit은 자동으로 하지 않는다 (사용자에게 제안만)
- npm install 등 의존성 설치는 자동으로 하지 않는다

### 문답 안전
- 코드에서 이미 확인된 사실을 다시 묻지 않는다
- 한 번에 3개 이상의 질문을 하지 않는다
- 사용자가 "몰라" 또는 "기본값으로"라고 답하면 합리적 기본값을 적용하고 진행한다

---

## 10. 에러 처리

| 상황 | 대응 |
|------|------|
| package.json이 없다 | "이 디렉토리는 Node.js 프로젝트가 아닌 것 같습니다" 안내 후 중단 |
| 매칭 프리셋이 없다 | 스캔 결과를 보여주고 문답으로 프로필 구성 (에러가 아님) |
| 이미 AGENTS.md가 있다 | "기존 AGENTS.md를 발견했습니다. 덮어쓸까요, 스킵할까요?" 확인 |
| 이미 CLAUDE.md가 있다 | "기존 CLAUDE.md를 발견했습니다. 덮어쓸까요, 스킵할까요?" 확인 |
| structural-test.ts 실행 실패 | 에러 내용을 보여주고 수동 수정 제안 |
| src/ 디렉토리가 없다 | 소스 루트를 자동 탐색, 못 찾으면 사용자에게 질문 |
| tsconfig paths가 없다 | 상대 경로 import 패턴으로 structural-test 조정 |
| 아키텍처 패턴을 분류할 수 없다 | "자유 구조"로 분류하고, 사용자에게 규칙이 있는지 질문 |
| 사용자가 문답에 "몰라"로 답변 | 합리적 기본값 적용, 보고에서 기본값 사용 항목을 명시 |
| 사용자가 아키텍처 감지 오류를 지적 | 아래 **재스캔/재생성 플로우** 참조 |

### 재스캔/재생성 플로우

Phase 1 진행 중 또는 Phase 4 보고 후 사용자가 아키텍처 감지, 프리셋 매칭, 또는 생성된 하네스의 오류를 지적하면 다음 절차를 따른다:

1. **Phase 1 중 (Step 4~5)**: 사용자의 피드백을 반영하여 프로필을 수정하고 Step 5(계획 제시)를 다시 진행한다. Phase 2를 시작하지 않은 상태이므로 파일 삭제 불필요.
2. **Phase 4 보고 후**: 사용자에게 어떤 파일을 재생성할지 확인한 뒤, 해당 파일만 덮어쓴다. 전체 재실행이 필요한 경우(아키텍처 유형 자체가 변경) Phase 1 Step 2부터 재시작하되, 이전 문답 내용은 유지한다.

재생성 가능 항목:
- AGENTS.md, CLAUDE.md, ARCHITECTURE.md — 프로필 수정 후 개별 재생성 가능
- scripts/structural-test.ts — 아키텍처 유형 또는 레이어 규칙 변경 시 재생성
- feature_list.json — 기능 목록 전체 재스캔 또는 항목 단위 수정
- init.sh — devServer 설정 변경 시 재생성

---

## 11. 커스텀 프리셋 작성 가이드

새 프리셋을 추가하려면:

1. `presets/` 폴더에 `{name}.json` 파일을 생성한다
2. 프리셋 스키마(섹션 8)의 모든 필수 필드를 채운다
3. `detection.required`에 해당 스택의 **고유 패키지**를 지정한다 (예: Remix → `"@remix-run/react"`)
4. `detection.versionConstraints`로 특정 버전 이상만 매칭되도록 제한한다 (선택)
5. `architecture.layers.rules`에서 각 레이어가 import할 수 있는 레이어를 명시한다
6. 기존 프리셋(`react-next.json`, `react-router-fsd.json`)을 참조 예시로 활용한다

**필수 필드 체크리스트:**
- `name`, `displayName`, `description`
- `detection.required` (최소 1개)
- `architecture.type`, `architecture.layers.order`, `architecture.layers.rules`
- `scripts.lint:arch`
- `devServer.command`, `devServer.port`
- `pathAlias`, `srcRoot`

---

## 12. 향후 확장 포인트

이 SKILL.md는 단일 스킬로 시작하되, 다음 방향으로 확장할 수 있다:

- **새 프리셋 추가**: `presets/react-vite.json`, `presets/express-api.json` 등
- **프로필 저장**: 문답으로 구성한 프로필을 JSON으로 저장하여 프리셋으로 재사용
- **멀티 에이전트 분리**: Scanner / Scaffolder / Validator를 별도 스킬로 분리
- **Coding Agent 스킬**: 하네스 위에서 실제 기능을 구현하는 세션 루틴 스킬
- **Cleanup Agent 스킬**: 주기적으로 문서/코드 일관성을 검사하는 정리 스킬
- **품질 대시보드**: QUALITY_SCORE.md를 자동 업데이트하는 스킬

---

## 13. 참고 자료

이 스킬 디렉토리의 `references/` 폴더에 상세 배경 문서가 있다.

### 우선순위 규칙
**SKILL.md가 정규 사양이다.** SKILL.md와 harness-guide.md의 내용이 충돌하면 SKILL.md가 우선한다. harness-guide.md는 배경 지식과 상세 예시를 위한 참조 자료이다.

### 스캐폴딩 시 참조 지침
Phase 2에서 파일을 생성할 때, 다음 참조를 읽어 구현의 기본 구조를 가져온다:

| 생성 파일 | 참조 위치 | 참조 방법 |
|-----------|----------|----------|
| scripts/structural-test.ts | `references/harness-guide.md` P8 섹션 | 기본 구조를 가져온 뒤 프로필의 LAYER_RULES로 치환 |
| scripts/doc-freshness.ts | `references/harness-guide.md` P10 섹션 | 기본 구조를 가져온 뒤 검사 대상 문서 목록을 프로필에 맞게 조정 |
| init.sh | `references/harness-guide.md` P5 섹션 | 기본 구조를 가져온 뒤 프로필의 devServer 값으로 치환 |
| AGENTS.md | `references/harness-guide.md` P2 섹션 | 형식 참고 (내용은 프로필 기반으로 작성) |

### 파일 목록
- `references/harness-guide.md` — Anthropic + OpenAI 하네스 엔지니어링 통합 가이드 (P1~P10 프로세스)
- `references/project-context.md` — 이 스킬의 설계 결정 기록, 버전 히스토리, 다음 단계
